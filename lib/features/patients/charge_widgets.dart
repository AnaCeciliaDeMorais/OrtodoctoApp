import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
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
      if (!forClient && c.status == ChargeStatus.paid && c.receivedByName != null)
        'Recebido por ${c.receivedByName}',
      if (!forClient && c.approvedByName != null && c.approvedBy != c.receivedBy)
        'Aprovado por ${c.approvedByName}',
      if (c.hasBoleto && c.status == ChargeStatus.open) 'Boleto gerado',
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
  final canReverse = paid && (isOwner || (c.receivedBy == session.profile?.id && c.approvedBy == null));

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(c.description), subtitle: Text('${f.money(c.amount)} · ${c.statusLabel}')),
          if (open) _a(ctx, Icons.payments_outlined, 'Receber pagamento', 'pay'),
          if (open && !c.hasBoleto) _a(ctx, Icons.receipt_outlined, 'Gerar boleto (Asaas)', 'boleto'),
          if (c.hasBoleto && c.boletoUrl != null) _a(ctx, Icons.open_in_new, 'Abrir boleto', 'open_boleto'),
          if (c.hasBoleto && c.boletoBarcode != null) _a(ctx, Icons.copy, 'Copiar linha digitável', 'copy'),
          if (open && c.hasBoleto) _a(ctx, Icons.cancel_outlined, 'Cancelar boleto', 'cancel_boleto'),
          if (paid && isOwner && c.approvedBy == null) _a(ctx, Icons.verified_outlined, 'Aprovar pagamento', 'approve'),
          if (canReverse) _a(ctx, Icons.undo, 'Estornar pagamento', 'reverse'),
          if (open) _a(ctx, Icons.edit_outlined, 'Editar', 'edit'),
          if (open && !c.hasBoleto) _a(ctx, Icons.block, 'Cancelar cobrança', 'cancel'),
          if (c.status == ChargeStatus.canceled) _a(ctx, Icons.restore, 'Reabrir cobrança', 'reopen'),
          if (!paid && !c.hasBoleto) _a(ctx, Icons.delete_outline, 'Excluir', 'delete'),
        ]),
      ),
    ),
  );
  if (action == null || !context.mounted) return false;

  switch (action) {
    case 'pay':
      final r = await showDialog<(String, DateTime)>(context: context, builder: (_) => _PayDialog(charge: c));
      if (r == null || !context.mounted) return false;
      return runGuarded(context, () => repo.pay(c.id, r.$1, r.$2),
          success: isOwner ? 'Pagamento recebido.' : 'Pagamento recebido. Aguarda aprovação do chefe.');
    case 'boleto':
      return runGuarded(context, () => repo.createBoleto(c.id), success: 'Boleto gerado.');
    case 'open_boleto':
      await launchUrl(Uri.parse(c.boletoUrl!), mode: LaunchMode.externalApplication);
      return false;
    case 'copy':
      await Clipboard.setData(ClipboardData(text: c.boletoBarcode!));
      if (context.mounted) showSnack(context, 'Linha digitável copiada.');
      return false;
    case 'cancel_boleto':
      if (!await confirm(context, 'Cancelar boleto', 'O boleto será cancelado no Asaas.', ok: 'Cancelar boleto')) {
        return false;
      }
      if (!context.mounted) return false;
      return runGuarded(context, () => repo.cancelBoleto(c.id), success: 'Boleto cancelado.');
    case 'approve':
      return runGuarded(context, () => repo.approve(c.id), success: 'Pagamento aprovado.');
    case 'reverse':
      if (!await confirm(context, 'Estornar pagamento',
          'A cobrança volta para "em aberto" e a entrada sai do caixa de quem recebeu.',
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

class _PayDialog extends StatefulWidget {
  const _PayDialog({required this.charge});
  final Charge charge;

  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  String _method = 'Pix';
  DateTime _date = f.dayOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receber pagamento'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${widget.charge.description}\n${f.money(widget.charge.amount)}'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Forma de pagamento'),
          items: [for (final m in paymentMethods) DropdownMenuItem(value: m, child: Text(m))],
          onChanged: (v) => setState(() => _method = v ?? _method),
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
        const SizedBox(height: 8),
        const Text('A entrada vai para o seu caixa.', style: TextStyle(fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, (_method, _date)), child: const Text('Confirmar')),
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
              decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ '),
              validator: Validators.money,
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
              const Text('Atenção: o boleto já gerado não muda. Cancele e gere outro se preciso.'),
          ],
        ),
      );
}

/// Nova cobrança: avulsa (1 parcela) ou parcelada (UC.3).
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
  int _count = 1;
  DateTime _due = f.dayOnly(DateTime.now());
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
        count: _count,
        firstDue: _due,
      ),
      success: _count == 1 ? 'Cobrança criada.' : '$_count parcelas criadas.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final total = f.parseMoney(_amount.text) ?? 0;
    return Form(
      key: _form,
      child: FormSheet(
        title: 'Nova cobrança',
        saving: _saving,
        onSave: _save,
        children: [
          TextFormField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Ex.: Aparelho ortodôntico'),
            validator: Validators.required,
          ),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor total', prefixText: r'R$ '),
            validator: Validators.money,
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<int>(
            initialValue: _count,
            decoration: const InputDecoration(labelText: 'Parcelas'),
            items: [
              for (var i = 1; i <= 24; i++)
                DropdownMenuItem(value: i, child: Text(i == 1 ? 'À vista (1x)' : '${i}x')),
            ],
            onChanged: (v) => setState(() => _count = v ?? 1),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text('${_count == 1 ? 'Vencimento' : '1º vencimento'}: ${f.date(_due)}'),
            onPressed: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _due, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _due = d);
            },
          ),
          if (_count > 1 && total > 0)
            Text('$_count parcelas de cerca de ${f.money(total / _count)}, vencendo todo mês.'),
        ],
      ),
    );
  }
}
