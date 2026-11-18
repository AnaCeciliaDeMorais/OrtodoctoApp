import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../home/company_switcher.dart';
import '../reports/sales_report.dart';
import 'cash_repository.dart';

/// Caixa (RF.14). Funcionário: só o próprio (RN.5).
/// Chefe: todos os caixas, por empresa ou geral, e por pessoa (RN.2).
class CashPage extends StatefulWidget {
  const CashPage({super.key});

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  final _repo = CashRepository();
  final _loader = GlobalKey<AsyncLoaderState<List<CashEntry>>>();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _companyId; // null = todas (chefe)
  String? _staffId; // null = todos (chefe)
  List<Profile> _people = [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final session = SessionScope.read(context);
    if (session.isOwner) {
      _companyId = session.current?.id;
      _loadPeople();
    } else {
      _companyId = session.current?.id;
      _staffId = session.profile?.id;
    }
  }

  List<String> get _companyIds {
    final session = SessionScope.read(context);
    return _companyId == null ? session.companies.map((c) => c.id).toList() : [_companyId!];
  }

  Future<void> _loadPeople() async {
    try {
      final people = await _repo.people(_companyIds);
      if (mounted) setState(() => _people = people);
    } catch (_) {}
  }

  DateTime get _from => _month;
  DateTime get _to => DateTime(_month.year, _month.month + 1, 0);

  Future<List<CashEntry>> _load() =>
      _repo.list(companyIds: _companyIds, staffId: _staffId, from: _from, to: _to);

  Future<void> _edit([CashEntry? e]) async {
    final session = SessionScope.read(context);
    final saved = await showFormSheet<bool>(
      context,
      (_) => CashEntrySheet(
        entry: e,
        companies: session.companies,
        initialCompanyId: e?.companyId ?? _companyId ?? session.current?.id,
      ),
    );
    if (saved == true) _loader.currentState?.reload();
  }

  /// Relatório de vendas do mês que está na tela, no modelo da Ana.
  /// Funcionário: sempre só o próprio caixa. Chefe: os filtros Empresa e "Caixa de".
  Future<void> _report(AppSession session, bool owner, bool pdf) async {
    final companyId = owner ? _companyId : session.current?.id;
    final company = companyId == null
        ? 'Todas as empresas'
        : session.companies.firstWhere((c) => c.id == companyId).name;
    final staffId = owner ? _staffId : session.profile?.id;
    final person = staffId == null
        ? 'Todos os caixas'
        : 'Caixa de ${_people.where((p) => p.id == staffId).firstOrNull?.fullName ?? session.profile?.fullName ?? ''}';
    await runGuarded(
      context,
      () => exportSalesReport(
        companyId: companyId,
        staffId: staffId,
        companyLabel: '$company · $person',
        month: _month,
        generatedBy: session.profile?.fullName ?? '',
        pdf: pdf,
      ),
      success: pdf ? null : 'Relatório de vendas gerado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final owner = session.isOwner;
    return RequireCompany(
      title: owner ? 'Caixa' : 'Meu caixa',
      child: Scaffold(
        appBar: AppBar(
          title: owner ? const Text('Caixa') : const CompanyTitle('Meu caixa'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<bool>(
                tooltip: 'Relatório de vendas do mês',
                onSelected: (pdf) => _report(session, owner, pdf),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: false,
                    child: ListTile(leading: Icon(Icons.table_view_outlined), title: Text('Planilha (.xlsx)')),
                  ),
                  PopupMenuItem(
                    value: true,
                    child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('PDF')),
                  ),
                ],
                child: const Chip(avatar: Icon(Icons.summarize_outlined, size: 18), label: Text('Relatório')),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Lançamento'),
        ),
        body: ContentWidth(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                IconButton(
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(f.monthYear(_month),
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ]),
            ),
            if (owner)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _companyId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Empresa'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas (geral)')),
                        for (final c in session.companies) DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _companyId = v;
                          _staffId = null;
                        });
                        _loadPeople();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('staff-$_companyId-${_people.length}'),
                      initialValue: _staffId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Caixa de'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        for (final p in _people)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(p.id == session.profile!.id ? '${p.fullName} (eu)' : p.fullName),
                          ),
                      ],
                      onChanged: (v) => setState(() => _staffId = v),
                    ),
                  ),
                ]),
              ),
            Expanded(
              child: AsyncLoader<List<CashEntry>>(
                key: _loader,
                reloadKey: '$_month|$_companyId|$_staffId',
                load: _load,
                builder: (context, entries, _) => _list(context, entries, owner),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<CashEntry> entries, bool owner) {
    final totalIn = entries.where((e) => e.isIn).fold<double>(0, (a, e) => a + e.amount);
    final totalOut = entries.where((e) => !e.isIn).fold<double>(0, (a, e) => a + e.amount);
    final scheme = Theme.of(context).colorScheme;
    final me = SessionScope.read(context).profile!.id;
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: SummaryTile(label: 'Entradas', value: f.money(totalIn), color: Colors.green.shade700)),
          const SizedBox(width: 8),
          Expanded(child: SummaryTile(label: 'Saídas', value: f.money(totalOut), color: scheme.error)),
          const SizedBox(width: 8),
          Expanded(child: SummaryTile(label: 'Saldo', value: f.money(totalIn - totalOut))),
        ]),
      ),
      if (entries.isEmpty)
        const EmptyState(icon: Icons.point_of_sale, message: 'Nenhum lançamento neste mês.')
      else
        for (final e in entries) ...[
          ListTile(
            leading: CircleAvatar(
              backgroundColor: (e.isIn ? Colors.green : scheme.error).withValues(alpha: 0.15),
              child: Icon(e.isIn ? Icons.arrow_downward : Icons.arrow_upward,
                  color: e.isIn ? Colors.green.shade700 : scheme.error),
            ),
            title: Text(e.description),
            subtitle: Text([
              f.date(e.occurredOn),
              if (e.patientName != null) e.patientName!,
              if (e.paymentMethod != null) e.paymentMethod!,
              if (owner && e.staffName != null) 'Caixa: ${e.staffName}',
              if (owner && _companyId == null && e.companyName != null) e.companyName!,
              if (e.fromCharge) 'Recebimento de cobrança',
            ].join(' · ')),
            trailing: Text(
              '${e.isIn ? '+' : '−'} ${f.money(e.amount)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: e.isIn ? Colors.green.shade700 : scheme.error),
            ),
            onTap: e.fromCharge
                ? () => showSnack(context, 'Recebimentos são estornados pela ficha do cliente.')
                : (owner || e.staffId == me)
                    ? () => _edit(e)
                    : null,
          ),
          const Divider(height: 1),
        ],
    ]);
  }
}

/// Lançamento manual de entrada ou saída no próprio caixa.
class CashEntrySheet extends StatefulWidget {
  const CashEntrySheet({super.key, this.entry, required this.companies, this.initialCompanyId});
  final CashEntry? entry;
  final List<Company> companies;
  final String? initialCompanyId;

  @override
  State<CashEntrySheet> createState() => _CashEntrySheetState();
}

class _CashEntrySheetState extends State<CashEntrySheet> {
  final _form = GlobalKey<FormState>();
  late CashKind _kind = widget.entry?.kind ?? CashKind.in_;
  late final _amount = TextEditingController(text: f.moneyInput(widget.entry?.amount));
  late final _desc = TextEditingController(text: widget.entry?.description);
  late String? _method = widget.entry?.paymentMethod ?? 'Dinheiro';
  late DateTime _date = widget.entry?.occurredOn ?? f.dayOnly(DateTime.now());
  late String? _companyId = widget.initialCompanyId ?? widget.companies.firstOrNull?.id;
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _companyId == null) return;
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => CashRepository().save(
        id: widget.entry?.id,
        companyId: _companyId!,
        kind: _kind,
        amount: f.parseMoney(_amount.text)!,
        description: _desc.text.trim(),
        method: _method,
        date: _date,
      ),
      success: 'Lançamento salvo.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Excluir lançamento', 'Excluir "${widget.entry!.description}"?',
        ok: 'Excluir', danger: true)) {
      return;
    }
    if (!mounted) return;
    if (await runGuarded(context, () => CashRepository().delete(widget.entry!.id))) {
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormSheet(
        title: widget.entry == null ? 'Novo lançamento' : 'Editar lançamento',
        saving: _saving,
        onSave: _save,
        extraActions: [
          if (widget.entry != null)
            IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
        children: [
          SegmentedButton<CashKind>(
            segments: const [
              ButtonSegment(value: CashKind.in_, label: Text('Entrada'), icon: Icon(Icons.arrow_downward)),
              ButtonSegment(value: CashKind.out, label: Text('Saída'), icon: Icon(Icons.arrow_upward)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          if (widget.companies.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _companyId,
              decoration: const InputDecoration(labelText: 'Empresa'),
              items: [for (final c in widget.companies) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _companyId = v),
            ),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ '),
            validator: Validators.money,
          ),
          TextFormField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'Descrição'),
            validator: Validators.required,
          ),
          DropdownButtonFormField<String>(
            initialValue: paymentMethods.contains(_method) ? _method : null,
            decoration: const InputDecoration(labelText: 'Forma'),
            items: [for (final m in paymentMethods) DropdownMenuItem(value: m, child: Text(m))],
            onChanged: (v) => setState(() => _method = v),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text('Data ${f.date(_date)}'),
            onPressed: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = d);
            },
          ),
        ],
      ),
    );
  }
}
