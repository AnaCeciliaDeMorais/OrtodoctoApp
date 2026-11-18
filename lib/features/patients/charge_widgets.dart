import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import 'patient_files_widgets.dart';
import 'patients_repository.dart';

/// Linha de cobrança usada na ficha do cliente, nas aprovações e na área do cliente.
class ChargeTile extends StatelessWidget {
  const ChargeTile({
    super.key,
    required this.charge,
    this.onTap,
    this.showPatient = false,
    this.forClient = false,
  });
  final Charge charge;
  final VoidCallback? onTap;
  final bool showPatient;

  /// Na área do cliente não aparecem detalhes internos (quem recebeu, aprovação).
  final bool forClient;

  @override
  Widget build(BuildContext context) {
    final c = charge;
    final lines = <String>[
      if (showPatient && c.patientName != null) c.patientName!,
      if (c.status == ChargeStatus.paid)
        'Pago em ${f.date(c.paidAt)}${c.paymentMethod != null ? ' · ${c.paymentMethod}' : ''}'
      else
        'Vence em ${f.date(c.dueDate)}',
      if (c.isPartial)
        'Pago ${f.money(c.paidAmount)} (${c.payments.map((p) => p.label).toSet().join(' + ')}) · falta ${f.money(c.remaining)}',
      if (!forClient && c.status == ChargeStatus.paid && c.receivedByName != null)
        'Recebido por ${c.receivedByName}',
      if (!forClient && c.approvedByName != null && c.approvedBy != c.receivedBy)
        'Aprovado por ${c.approvedByName}',
      if (c.hasBoleto && c.status == ChargeStatus.open) 'Boleto anexado',
    ];
    return ListTile(
      onTap: onTap,
      title: Text(c.description),
      subtitle: Text(lines.join('\n')),
      isThreeLine: lines.length > 1,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(f.money(c.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (c.pendingApproval && !forClient)
            const StatusChip('Aguardando aprovação', Colors.indigo)
          else
            StatusChip(c.statusLabel, c.statusColor(context)),
        ],
      ),
    );
  }
}

/// Menu de ações de uma cobrança para quem gerencia. Devolve true se algo mudou.
Future<bool> showChargeActions(BuildContext context, Charge c) async {
  final session = SessionScope.read(context);
  final repo = ChargesRepository();
  final isOwner = session.isOwner;
  final open = c.status == ChargeStatus.open;
  final paid = c.status == ChargeStatus.paid;
  final me = session.profile?.id;
  final canReverse = (paid || c.isPartial) &&
      (isOwner ||
          (c.approvedBy == null &&
              (!paid || c.receivedBy == me) &&
              c.payments.every((p) => p.receivedBy == me)));

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(c.description),
            subtitle: Text([
              '${f.money(c.amount)} · ${c.statusLabel}',
              if (c.isPartial) 'Já pago ${f.money(c.paidAmount)} · falta ${f.money(c.remaining)}',
            ].join('\n')),
          ),
          if (open) _a(ctx, Icons.payments_outlined, c.isPartial ? 'Receber o restante' : 'Receber pagamento', 'pay'),
          for (final file in c.files)
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text('Abrir: ${file.title}'),
              onTap: () => Navigator.pop(ctx, 'open:${file.id}'),
            ),
          if (open) _a(ctx, Icons.attach_file, c.hasBoleto ? 'Anexar outro boleto' : 'Anexar boleto', 'attach'),
          if (c.hasBoleto) _a(ctx, Icons.delete_outline, 'Remover boleto anexado', 'remove_boleto'),
          if (paid && isOwner && c.approvedBy == null) _a(ctx, Icons.verified_outlined, 'Aprovar pagamento', 'approve'),
          if (canReverse)
            _a(ctx, Icons.undo, c.isPartial ? 'Estornar pagamentos recebidos' : 'Estornar pagamento', 'reverse'),
          if (open) _a(ctx, Icons.edit_outlined, 'Editar', 'edit'),
          if (open && !c.isPartial) _a(ctx, Icons.block, 'Cancelar cobrança', 'cancel'),
          if (c.status == ChargeStatus.canceled) _a(ctx, Icons.restore, 'Reabrir cobrança', 'reopen'),
          if (!paid && !c.isPartial) _a(ctx, Icons.delete_outline, 'Excluir cobrança', 'delete'),
        ]),
      ),
    ),
  );
  if (action == null || !context.mounted) return false;

  if (action.startsWith('open:')) {
    final file = c.files.firstWhere((x) => 'open:${x.id}' == action);
    await openPatientFile(context, file);
    return false;
  }

  switch (action) {
    case 'pay':
      final r = await showDialog<_Receipt>(context: context, builder: (_) => ReceivePaymentDialog(charge: c));
      if (r == null || !context.mounted) return false;
      final total = r.parts.fold<double>(0, (a, p) => a + p.amount);
      final partial = total < c.remaining - 0.005;
      return runGuarded(
        context,
        () => repo.receivePayment(c.id, parts: r.parts, paidOn: r.date, interest: r.interest),
        success: partial
            ? 'Pagamento parcial recebido. Falta ${f.money(c.remaining - total)}.'
            : (isOwner ? 'Pagamento recebido.' : 'Pagamento recebido. Aguarda aprovação do chefe.'),
      );
    case 'attach':
      final saved = await showFormSheet<bool>(
        context,
        (_) => UploadPatientFileSheet(companyId: c.companyId, patientId: c.patientId, charge: c),
      );
      return saved == true;
    case 'remove_boleto':
      if (c.files.length == 1) return deletePatientFile(context, c.files.single);
      final file = await showModalBottomSheet<PatientFile>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(title: Text('Qual boleto remover?')),
            for (final x in c.files)
              ListTile(leading: const Icon(Icons.delete_outline), title: Text(x.title), onTap: () => Navigator.pop(ctx, x)),
          ]),
        ),
      );
      if (file == null || !context.mounted) return false;
      return deletePatientFile(context, file);
    case 'approve':
      return runGuarded(context, () => repo.approve(c.id), success: 'Pagamento aprovado.');
    case 'reverse':
      if (!await confirm(context, 'Estornar pagamento',
          'Todos os pagamentos desta cobrança são desfeitos: ela volta para "em aberto" '
          'e as entradas saem do caixa de quem recebeu.',
          ok: 'Estornar', danger: true)) {
        return false;
      }
      if (!context.mounted) return false;
      return runGuarded(context, () => repo.reverse(c.id), success: 'Pagamento estornado.');
    case 'edit':
      final saved = await showFormSheet<bool>(context, (_) => _EditChargeSheet(charge: c));
      return saved == true;
    case 'cancel':
      return runGuarded(context, () => repo.cancel(c.id), success: 'Cobrança cancelada.');
    case 'reopen':
      return runGuarded(context, () => repo.reopen(c.id), success: 'Cobrança reaberta.');
    case 'delete':
      if (!await confirm(context, 'Excluir cobrança', 'Excluir "${c.description}"?', ok: 'Excluir', danger: true)) {
        return false;
      }
      if (!context.mounted) return false;
      return runGuarded(context, () => repo.delete(c.id), success: 'Cobrança excluída.');
  }
  return false;
}

Widget _a(BuildContext ctx, IconData icon, String label, String value) =>
    ListTile(leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(ctx, value));

class _Receipt {
  _Receipt(this.parts, this.date, this.interest);
  final List<PaymentPart> parts;
  final DateTime date;
  final double interest;
}

class _PartInput {
  _PartInput(this.method, String amount) : amount = TextEditingController(text: amount);
  String method;
  int installments = 1;
  final TextEditingController amount;
}

/// Dar baixa: uma ou mais formas de pagamento (ex.: Pix + cartão em 3x),
/// e o valor pode ser menor que o total (pagamento parcial).
class ReceivePaymentDialog extends StatefulWidget {
  const ReceivePaymentDialog({super.key, required this.charge});
  final Charge charge;

  @override
  State<ReceivePaymentDialog> createState() => _ReceivePaymentDialogState();
}

class _ReceivePaymentDialogState extends State<ReceivePaymentDialog> {
  late final List<_PartInput> _parts = [_PartInput('Pix', f.moneyInput(widget.charge.remaining))];
  final _interest = TextEditingController();
  DateTime _date = f.dayOnly(DateTime.now());

  @override
  void dispose() {
    for (final p in _parts) {
      p.amount.dispose();
    }
    _interest.dispose();
    super.dispose();
  }

  double get _remaining => widget.charge.remaining;
  double get _total => _parts.fold<double>(0, (a, p) => a + (f.parseMoney(p.amount.text) ?? 0));
  bool get _allValid => _parts.every((p) => (f.parseMoney(p.amount.text) ?? 0) > 0);
  bool get _tooMuch => _total > _remaining + 0.005;

  void _addPart() {
    final left = _remaining - _total;
    setState(() => _parts.add(_PartInput(
          _parts.any((p) => p.method == creditCardMethod) ? 'Dinheiro' : creditCardMethod,
          left > 0.005 ? f.moneyInput(left) : '',
        )));
  }

  void _confirm() {
    Navigator.pop(
      context,
      _Receipt(
        [
          for (final p in _parts)
            PaymentPart(p.method, double.parse(f.parseMoney(p.amount.text)!.toStringAsFixed(2)), p.installments),
        ],
        _date,
        f.parseMoney(_interest.text) ?? 0,
      ),
    );
  }

  Widget _partRow(int i) {
    final p = _parts[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: p.method,
              isExpanded: true,
              decoration: InputDecoration(labelText: _parts.length > 1 ? 'Forma ${i + 1}' : 'Forma de pagamento'),
              items: [for (final m in paymentMethods) DropdownMenuItem(value: m, child: Text(m))],
              onChanged: (v) => setState(() {
                p.method = v ?? p.method;
                if (p.method != creditCardMethod) p.installments = 1;
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: p.amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ '),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_parts.length > 1)
            IconButton(
              tooltip: 'Remover esta forma',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _parts.removeAt(i).amount.dispose()),
            ),
        ]),
        if (p.method == creditCardMethod) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: p.installments,
            decoration: const InputDecoration(labelText: 'Parcelas no cartão'),
            items: [
              for (var n = 1; n <= 12; n++)
                DropdownMenuItem(value: n, child: Text(n == 1 ? 'À vista (1x)' : '${n}x')),
            ],
            onChanged: (v) => setState(() => p.installments = v ?? 1),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.charge;
    final total = _total;
    final left = _remaining - total;
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text('Receber pagamento'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c.description, style: Theme.of(context).textTheme.titleSmall),
            Text(c.isPartial
                ? 'Total ${f.money(c.amount)} · já pago ${f.money(c.paidAmount)} · falta ${f.money(_remaining)}'
                : 'Valor ${f.money(c.amount)}'),
            const SizedBox(height: 16),
            for (var i = 0; i < _parts.length; i++) _partRow(i),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Outra forma de pagamento'),
                onPressed: _parts.length >= 6 ? null : _addPart,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _interest,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Juros / multa (opcional)',
                prefixText: r'R$ ',
                helperText: 'Somado à entrada no caixa; não abate da cobrança.',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text('Pago em ${f.date(_date)}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            if (_tooMuch)
              Text('A soma (${f.money(total)}) passa do valor em aberto (${f.money(_remaining)}).',
                  style: TextStyle(color: error))
            else if (left > 0.005 && total > 0)
              Text('Pagamento parcial: depois desta baixa ainda vão faltar ${f.money(left)}. '
                  'A cobrança continua em aberto.')
            else if (total > 0)
              const Text('Quita a cobrança.'),
            const SizedBox(height: 4),
            const Text('A entrada vai para o seu caixa.', style: TextStyle(fontSize: 12)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _allValid && !_tooMuch && total > 0 ? _confirm : null,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _EditChargeSheet extends StatefulWidget {
  const _EditChargeSheet({required this.charge});
  final Charge charge;

  @override
  State<_EditChargeSheet> createState() => _EditChargeSheetState();
}

class _EditChargeSheetState extends State<_EditChargeSheet> {
  final _form = GlobalKey<FormState>();
  late final _desc = TextEditingController(text: widget.charge.description);
  late final _amount = TextEditingController(text: f.moneyInput(widget.charge.amount));
  late DateTime _due = widget.charge.dueDate;
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => ChargesRepository().update(widget.charge.id,
          description: _desc.text.trim(), amount: f.parseMoney(_amount.text)!, due: _due),
      success: 'Cobrança salva.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: FormSheet(
          title: 'Editar cobrança',
          saving: _saving,
          onSave: _save,
          children: [
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Descrição'),
              validator: Validators.required,
            ),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor',
                prefixText: r'R$ ',
                helperText: widget.charge.isPartial ? 'Já pago: ${f.money(widget.charge.paidAmount)}' : null,
              ),
              validator: (v) {
                final base = Validators.money(v);
                if (base != null) return base;
                if ((f.parseMoney(v ?? '') ?? 0) < widget.charge.paidAmount - 0.005) {
                  return 'Não pode ser menor que o já pago (${f.money(widget.charge.paidAmount)}).';
                }
                return null;
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text('Vencimento ${f.date(_due)}'),
              onPressed: () async {
                final d = await showDatePicker(
                    context: context, initialDate: _due, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => _due = d);
              },
            ),
            if (widget.charge.hasBoleto)
              const Text('Atenção: o arquivo do boleto anexado não muda. Se o valor ou o vencimento mudar, '
                  'remova o boleto e anexe o novo.'),
          ],
        ),
      );
}

/// Nova cobrança: só descrição e valor. Vencimento fica para hoje (dá para
/// mudar depois em "Editar"). A forma de pagamento é escolhida na baixa.
class NewChargeSheet extends StatefulWidget {
  const NewChargeSheet({super.key, required this.patientId});
  final String patientId;

  @override
  State<NewChargeSheet> createState() => _NewChargeSheetState();
}

class _NewChargeSheetState extends State<NewChargeSheet> {
  final _form = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => ChargesRepository().createInstallments(
        patientId: widget.patientId,
        description: _desc.text.trim(),
        total: f.parseMoney(_amount.text)!,
        count: 1,
        firstDue: f.dayOnly(DateTime.now()),
      ),
      success: 'Cobrança criada.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormSheet(
        title: 'Nova cobrança',
        saving: _saving,
        onSave: _save,
        children: [
          TextFormField(
            controller: _desc,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: Aparelho ortodôntico'),
            validator: Validators.required,
          ),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ '),
            validator: Validators.money,
          ),
        ],
      ),
    );
  }
}
