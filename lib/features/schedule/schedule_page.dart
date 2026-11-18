import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../companies/clinic_days_page.dart';
import '../home/company_switcher.dart';
import 'appointment_sheet.dart';
import 'schedule_repository.dart';

class _DayData {
  _DayData(this.appointments, this.clinicDays, this.anyConfigured);
  final List<Appointment> appointments;
  final List<ClinicDay> clinicDays;
  final bool anyConfigured;
}

/// Agenda da empresa (RF.6, RF.8): dias da semana no topo e horários do dia.
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _repo = ScheduleRepository();
  DateTime _date = f.dayOnly(DateTime.now());
  bool _onlyBusy = false;
  final _loader = GlobalKey<AsyncLoaderState<_DayData>>();

  DateTime get _weekStart => _date.subtract(Duration(days: _date.weekday - 1));

  Future<_DayData> _load(Company company) async {
    final from = _date.subtract(const Duration(days: 90));
    final to = _date.add(const Duration(days: 90));
    final results = await Future.wait([
      _repo.range(company.id, _date, _date.add(const Duration(days: 1))),
      _repo.clinicDays(company.id, from, to),
    ]);
    final days = results[1] as List<ClinicDay>;
    return _DayData(results[0] as List<Appointment>, days, days.isNotEmpty);
  }

  void _go(DateTime d) => setState(() => _date = f.dayOnly(d));

  Future<void> _edit({Appointment? appointment, DateTime? at}) async {
    final company = SessionScope.read(context).current!;
    final saved = await showFormSheet<bool>(
      context,
      (_) => AppointmentSheet(company: company, appointment: appointment, initialStart: at ?? _date),
    );
    if (saved == true) _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return RequireCompany(
      title: 'Agenda',
      child: Builder(builder: (context) {
        final session = SessionScope.of(context);
        final company = session.current!;
        return Scaffold(
          appBar: AppBar(
            title: const CompanyTitle('Agenda'),
            actions: [
              IconButton(
                tooltip: 'Hoje',
                icon: const Icon(Icons.today),
                onPressed: () => _go(DateTime.now()),
              ),
              IconButton(
                tooltip: 'Escolher data',
                icon: const Icon(Icons.calendar_month),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) _go(d);
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Novo agendamento',
            onPressed: () => _edit(),
            child: const Icon(Icons.add),
          ),
          body: ContentWidth(
            child: Column(children: [
              _WeekStrip(
                weekStart: _weekStart,
                selected: _date,
                onSelect: _go,
                onPrev: () => _go(_date.subtract(const Duration(days: 7))),
                onNext: () => _go(_date.add(const Duration(days: 7))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                child: Row(children: [
                  Expanded(
                    child: Text(f.dayLong(_date), style: Theme.of(context).textTheme.titleMedium),
                  ),
                  FilterChip(
                    label: const Text('Só ocupados'),
                    selected: _onlyBusy,
                    onSelected: (v) => setState(() => _onlyBusy = v),
                  ),
                ]),
              ),
              Expanded(
                child: AsyncLoader<_DayData>(
                  key: _loader,
                  reloadKey: _date,
                  load: () => _load(company),
                  builder: (context, data, _) => _dayView(context, company, data, session.isOwner),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _dayView(BuildContext context, Company company, _DayData data, bool isOwner) {
    ClinicDay? day;
    for (final d in data.clinicDays) {
      if (f.dayOnly(d.day) == _date) day = d;
    }
    final isWeekday = _date.weekday <= DateTime.friday;
    final open = day != null || (!data.anyConfigured && isWeekday);
    final slots = open ? slotsFor(_date, company, day) : <DateTime>[];

    // Junta horários da grade com agendamentos fora da grade.
    final byTime = <DateTime, List<Appointment>>{for (final s in slots) s: []};
    for (final a in data.appointments) {
      final key = DateTime(a.startsAt.year, a.startsAt.month, a.startsAt.day, a.startsAt.hour, a.startsAt.minute);
      byTime.putIfAbsent(key, () => []).add(a);
    }
    var times = byTime.keys.toList()..sort();
    if (_onlyBusy) times = times.where((t) => byTime[t]!.isNotEmpty).toList();

    final header = <Widget>[
      if (!open)
        Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ListTile(
            leading: const Icon(Icons.event_busy),
            title: const Text('Sem atendimento neste dia'),
            subtitle: Text(isOwner
                ? 'Cadastre o dia em "Dias de atendimento" para abrir a agenda.'
                : 'O chefe define os dias de atendimento.'),
            trailing: isOwner
                ? TextButton(
                    onPressed: () async {
                      await Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const ClinicDaysPage()));
                      _loader.currentState?.reload();
                    },
                    child: const Text('Abrir dia'),
                  )
                : null,
          ),
        ),
      if (day?.notes != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(day!.notes!, style: Theme.of(context).textTheme.bodySmall),
        ),
    ];

    if (times.isEmpty) {
      return ListView(children: [
        ...header,
        EmptyState(
          icon: Icons.event_available,
          message: _onlyBusy ? 'Nenhum agendamento neste dia.' : 'Nenhum horário disponível.',
        ),
      ]);
    }

    final active = data.appointments.where((a) => a.isActive).length;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: times.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) return Column(children: header);
        if (i == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('$active agendamento(s)', style: Theme.of(context).textTheme.bodySmall),
          );
        }
        final t = times[i - 2];
        final list = byTime[t]!;
        final free = company.maxPerSlot - list.where((a) => a.isActive).length;
        return _SlotRow(
          time: t,
          appointments: list,
          canAdd: free > 0,
          onAdd: () => _edit(at: t),
          onOpen: (a) => _edit(appointment: a),
        );
      },
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selected,
    required this.onSelect,
    required this.onPrev,
    required this.onNext,
  });
  final DateTime weekStart;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = f.dayOnly(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left), tooltip: 'Semana anterior'),
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final d = weekStart.add(Duration(days: i));
            final isSel = d == selected;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? scheme.primary : null,
                    borderRadius: BorderRadius.circular(12),
                    border: d == today && !isSel ? Border.all(color: scheme.primary) : null,
                  ),
                  child: Column(children: [
                    Text(f.weekdayShort(d),
                        style: TextStyle(fontSize: 11, color: isSel ? scheme.onPrimary : null)),
                    Text('${d.day}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSel ? scheme.onPrimary : null)),
                  ]),
                ),
              ),
            );
          }),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right), tooltip: 'Próxima semana'),
      ]),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.time,
    required this.appointments,
    required this.canAdd,
    required this.onAdd,
    required this.onOpen,
  });
  final DateTime time;
  final List<Appointment> appointments;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<Appointment> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(f.time(time), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in appointments)
              ActionChip(
                avatar: CircleAvatar(backgroundColor: a.status.color, radius: 6),
                label: Text(
                  [a.patientName ?? 'Cliente', if (a.label != null) a.label!].join(' · '),
                  style: a.status == AppointmentStatus.canceled
                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                      : null,
                ),
                onPressed: () => onOpen(a),
              ),
            if (canAdd)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(appointments.isEmpty ? 'Livre' : 'Encaixar'),
                onPressed: onAdd,
              ),
          ]),
        ),
      ]),
    );
  }
}
