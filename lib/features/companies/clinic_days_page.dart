import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../home/company_switcher.dart';
import 'companies_repository.dart';

/// Chefe: define os dias em que a agenda fica aberta (RF.7 / RN.3).
/// Sem nenhum dia cadastrado, a agenda abre de segunda a sexta no horário
/// padrão da empresa.
class ClinicDaysPage extends StatefulWidget {
  const ClinicDaysPage({super.key});

  @override
  State<ClinicDaysPage> createState() => _ClinicDaysPageState();
}

class _ClinicDaysPageState extends State<ClinicDaysPage> {
  final _repo = CompaniesRepository();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final _loader = GlobalKey<AsyncLoaderState<List<ClinicDay>>>();

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    return RequireCompany(
      title: 'Dias de atendimento',
      child: Builder(builder: (context) {
        final company = SessionScope.of(context).current!;
        final last = DateTime(_month.year, _month.month + 1, 0);
        return Scaffold(
          appBar: AppBar(title: const CompanyTitle('Dias de atendimento')),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Adicionar dias'),
            onPressed: () async {
              final saved = await showFormSheet<bool>(
                  context, (_) => _AddDaysSheet(company: company, month: _month));
              if (saved == true) _loader.currentState?.reload();
            },
          ),
          body: ContentWidth(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: Text(f.monthYear(_month),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                ]),
              ),
              Expanded(
                child: AsyncLoader<List<ClinicDay>>(
                  key: _loader,
                  reloadKey: _month,
                  load: () => _repo.clinicDays(company.id, _month, last),
                  builder: (context, days, reload) {
                    if (days.isEmpty) {
                      return ListView(children: [
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.event_busy,
                          message: 'Nenhum dia cadastrado neste mês.\n'
                              'Sem dias cadastrados, a agenda abre de segunda a sexta, '
                              'das ${company.openingTime} às ${company.closingTime}.',
                        ),
                      ]);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: days.length,
                      itemBuilder: (context, i) {
                        final d = days[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${d.day.day}')),
                          title: Text(f.dayLong(d.day)),
                          subtitle: Text([d.hoursLabel, if (d.notes != null) d.notes!].join(' · ')),
                          trailing: IconButton(
                            tooltip: 'Remover dia',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (await runGuarded(context, () => _repo.deleteClinicDay(d.id))) {
                                reload();
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

class _AddDaysSheet extends StatefulWidget {
  const _AddDaysSheet({required this.company, required this.month});
  final Company company;
  final DateTime month;

  @override
  State<_AddDaysSheet> createState() => _AddDaysSheetState();
}

class _AddDaysSheetState extends State<_AddDaysSheet> {
  late DateTimeRange _range = DateTimeRange(
    start: f.dayOnly(DateTime.now()).isAfter(widget.month) ? f.dayOnly(DateTime.now()) : widget.month,
    end: DateTime(widget.month.year, widget.month.month + 1, 0),
  );
  final Set<int> _weekdays = {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday};
  late String _start = widget.company.openingTime;
  late String _end = widget.company.closingTime;
  String? _breakStart = '12:00';
  String? _breakEnd = '13:00';
  final _notes = TextEditingController();
  bool _saving = false;

  static const _names = {1: 'Seg', 2: 'Ter', 3: 'Qua', 4: 'Qui', 5: 'Sex', 6: 'Sáb', 7: 'Dom'};

  List<DateTime> get _days {
    final out = <DateTime>[];
    for (var d = _range.start; !d.isAfter(_range.end); d = DateTime(d.year, d.month, d.day + 1)) {
      if (_weekdays.contains(d.weekday)) out.add(d);
    }
    return out;
  }

  Future<String?> _time(String? current) async {
    final c = f.parseTime(current ?? '12:00');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: c.h, minute: c.m));
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final days = _days;
    if (days.isEmpty) {
      showSnack(context, 'Nenhum dia no período escolhido.', error: true);
      return;
    }
    if (_end.compareTo(_start) <= 0) {
      showSnack(context, 'O horário final precisa ser depois do inicial.', error: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => CompaniesRepository().saveClinicDays(
        companyId: widget.company.id,
        days: days,
        start: _start,
        end: _end,
        breakStart: _breakStart,
        breakEnd: _breakStart == null ? null : _breakEnd,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
      success: '${days.length} dia(s) salvos.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Adicionar dias de atendimento',
      saving: _saving,
      saveLabel: 'Salvar ${_days.length} dia(s)',
      onSave: _save,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text('${f.date(_range.start)} até ${f.date(_range.end)}'),
          onPressed: () async {
            final r = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              initialDateRange: _range,
            );
            if (r != null) setState(() => _range = r);
          },
        ),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in _names.entries)
            FilterChip(
              label: Text(e.value),
              selected: _weekdays.contains(e.key),
              onSelected: (v) => setState(() => v ? _weekdays.add(e.key) : _weekdays.remove(e.key)),
            ),
        ]),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final t = await _time(_start);
                if (t != null) setState(() => _start = t);
              },
              child: Text('Início $_start'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final t = await _time(_end);
                if (t != null) setState(() => _end = t);
              },
              child: Text('Fim $_end'),
            ),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pausa para almoço'),
          value: _breakStart != null,
          onChanged: (v) => setState(() {
            _breakStart = v ? '12:00' : null;
            _breakEnd = v ? '13:00' : null;
          }),
        ),
        if (_breakStart != null)
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await _time(_breakStart);
                  if (t != null) setState(() => _breakStart = t);
                },
                child: Text('De $_breakStart'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await _time(_breakEnd);
                  if (t != null) setState(() => _breakEnd = t);
                },
                child: Text('Até $_breakEnd'),
              ),
            ),
          ]),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(labelText: 'Observação (opcional)'),
        ),
        const Text('Dias que já existem no período são atualizados com estes horários.'),
      ],
    );
  }
}
