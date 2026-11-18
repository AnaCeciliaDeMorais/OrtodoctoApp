import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import 'reports_pdf.dart';
import 'reports_repository.dart';

enum _Period { thisMonth, lastMonth, thisYear, custom }

/// Relatórios do chefe (RF.4 / RN.2): por empresa ou de todas juntas.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _repo = ReportsRepository();
  String? _companyId;
  _Period _period = _Period.thisMonth;
  late DateTimeRange _range = _rangeFor(_Period.thisMonth);
  ReportData? _last;

  static DateTimeRange _rangeFor(_Period p) {
    final now = DateTime.now();
    return switch (p) {
      _Period.thisMonth => DateTimeRange(start: DateTime(now.year, now.month), end: DateTime(now.year, now.month + 1, 0)),
      _Period.lastMonth => DateTimeRange(start: DateTime(now.year, now.month - 1), end: DateTime(now.year, now.month, 0)),
      _Period.thisYear => DateTimeRange(start: DateTime(now.year), end: DateTime(now.year, 12, 31)),
      _Period.custom => DateTimeRange(start: DateTime(now.year, now.month), end: f.dayOnly(now)),
    };
  }

  Future<void> _choosePeriod(_Period p) async {
    if (p == _Period.custom) {
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: _range,
      );
      if (r == null) return;
      setState(() {
        _period = p;
        _range = r;
      });
    } else {
      setState(() {
        _period = p;
        _range = _rangeFor(p);
      });
    }
  }

  String get _companyLabel {
    if (_companyId == null) return 'Todas as empresas';
    return SessionScope.read(context).companies.firstWhere((c) => c.id == _companyId).name;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          IconButton(
            tooltip: 'Exportar PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _last == null
                ? null
                : () => runGuarded(
                      context,
                      () => exportReportsPdf(
                        data: _last!,
                        companyLabel: _companyLabel,
                        period: '${f.date(_range.start)} a ${f.date(_range.end)}',
                        allCompanies: _companyId == null,
                      ),
                    ),
          ),
        ],
      ),
      body: ContentWidth(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String?>(
              initialValue: _companyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Empresa'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas (relatório geral)')),
                for (final c in session.companies) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _companyId = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              for (final p in _Period.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(switch (p) {
                      _Period.thisMonth => 'Este mês',
                      _Period.lastMonth => 'Mês passado',
                      _Period.thisYear => 'Este ano',
                      _Period.custom => _period == _Period.custom
                          ? '${f.dateShort(_range.start)}–${f.dateShort(_range.end)}'
                          : 'Escolher período',
                    }),
                    selected: _period == p,
                    onSelected: (_) => _choosePeriod(p),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: AsyncLoader<ReportData>(
              reloadKey: '$_companyId|${_range.start}|${_range.end}',
              load: () async {
                final d = await _repo.load(companyId: _companyId, from: _range.start, to: _range.end);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _last = d);
                });
                return d;
              },
              builder: (context, data, _) => _content(context, data),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _content(BuildContext context, ReportData d) {
    final all = _companyId == null;
    final totalIn = d.revenue.fold<double>(0, (a, r) => a + r.totalIn);
    final totalOut = d.revenue.fold<double>(0, (a, r) => a + r.totalOut);
    final overdueTotal = d.overdue.fold<double>(0, (a, r) => a + r.amount);
    final apptTotal = d.appointments.fold<int>(0, (a, r) => a + r.total);
    final maxIn = d.revenue.fold<double>(0, (a, r) => r.totalIn > a ? r.totalIn : a);
    final scheme = Theme.of(context).colorScheme;

    final byStatus = <String, int>{};
    for (final r in d.appointments) {
      byStatus[r.status] = (byStatus[r.status] ?? 0) + r.total;
    }

    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            SummaryTile(label: 'Faturamento (entradas)', value: f.money(totalIn), color: Colors.green.shade700),
            SummaryTile(label: 'Saldo do caixa', value: f.money(totalIn - totalOut)),
            SummaryTile(label: 'Inadimplência', value: f.money(overdueTotal), color: scheme.error),
            SummaryTile(label: 'Atendimentos', value: '$apptTotal'),
          ],
        ),
      ),

      const SectionTitle('Faturamento por mês'),
      if (d.revenue.isEmpty)
        const _None()
      else
        for (final r in d.revenue)
          ListTile(
            title: Text(all ? '${f.monthYear(r.month)} · ${r.companyName}' : f.monthYear(r.month)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: maxIn == 0 ? 0 : r.totalIn / maxIn,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 4),
              Text('Entradas ${f.money(r.totalIn)} · Saídas ${f.money(r.totalOut)}'),
            ]),
            trailing: Text(f.money(r.balance), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),

      SectionTitle('Inadimplência (${d.overdue.length})'),
      if (d.overdue.isEmpty)
        const _None('Nenhuma cobrança vencida.')
      else
        for (final r in d.overdue)
          ListTile(
            title: Text(r.patientName),
            subtitle: Text([
              r.description,
              'Venceu ${f.date(r.dueDate)} (${r.daysLate} dias)',
              if (r.phone != null) f.phone(r.phone),
              if (all) r.companyName,
            ].join(' · ')),
            trailing: Text(f.money(r.amount), style: TextStyle(fontWeight: FontWeight.bold, color: scheme.error)),
          ),

      const SectionTitle('Atendimentos no período'),
      if (d.appointments.isEmpty)
        const _None()
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in byStatus.entries)
              Chip(
                avatar: CircleAvatar(backgroundColor: AppointmentStatus.parse(e.key).color, radius: 6),
                label: Text('${AppointmentStatus.parse(e.key).label}: ${e.value}'),
              ),
          ]),
        ),
        if (all)
          for (final r in d.appointments)
            ListTile(
              dense: true,
              title: Text(r.companyName),
              trailing: Text('${AppointmentStatus.parse(r.status).label}: ${r.total}'),
            ),
      ],

      const SectionTitle('Caixa por funcionário'),
      if (d.staffCash.isEmpty)
        const _None()
      else
        for (final r in d.staffCash)
          ListTile(
            title: Text(all ? '${r.staffName} · ${r.companyName}' : r.staffName),
            subtitle: Text('Entradas ${f.money(r.totalIn)} · Saídas ${f.money(r.totalOut)}\n'
                'Recebimentos: ${r.received} · aprovados em 2 etapas: ${r.twoStep} · '
                'aguardando aprovação: ${r.pending}'),
            isThreeLine: true,
            trailing: Text(f.money(r.balance), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
    ]);
  }
}

class _None extends StatelessWidget {
  const _None([this.text = 'Sem dados no período.']);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
