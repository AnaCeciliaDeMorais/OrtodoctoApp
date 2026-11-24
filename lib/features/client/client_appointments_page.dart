import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../schedule/schedule_repository.dart';
import 'client_reminders.dart';

/// Quantos dias à frente mostrar os dias de atendimento da clínica.
const _clinicDaysAhead = 60;

class _Data {
  _Data(this.appointments, this.clinicDays);
  final List<Appointment> appointments;
  final List<ClinicDay> clinicDays;
}

/// Consultas do cliente (RN.9). Agendar é feito pela clínica (RN.11).
/// Mostra também o retorno de prevenção e os dias de atendimento da clínica.
class ClientAppointmentsPage extends StatelessWidget {
  const ClientAppointmentsPage({super.key});

  Future<_Data> _load(List<Company> companies) async {
    final today = f.dayOnly(DateTime.now());
    final until = today.add(const Duration(days: _clinicDaysAhead));
    final repo = ScheduleRepository();
    final r = await Future.wait([
      repo.mine(),
      Future.wait(companies.map((c) => repo.clinicDays(c.id, today, until))),
    ]);
    final days = (r[1] as List<List<ClinicDay>>).expand((e) => e).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return _Data(r[0] as List<Appointment>, days);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final companies = session.companies;
    final several = companies.length > 1;
    String companyName(String id) => companies.where((c) => c.id == id).firstOrNull?.name ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Minhas consultas')),
      body: ContentWidth(
        child: AsyncLoader<_Data>(
          load: () => _load(companies),
          builder: (context, d, _) {
            final items = d.appointments;
            final now = DateTime.now();
            final upcoming = items.where((a) => a.startsAt.isAfter(now) && a.isActive).toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            final past = items.where((a) => !upcoming.contains(a)).toList();
            final prevention = preventionReturn(items);
            final scheme = Theme.of(context).colorScheme;

            Widget tile(Appointment a) => ListTile(
                  leading: Icon(Icons.event, color: a.status.color),
                  title: Text(f.dateTime(a.startsAt)),
                  subtitle: Text([
                    if (a.label != null) a.label!,
                    if (several && a.companyName != null) a.companyName!,
                  ].join(' · ')),
                  trailing: StatusChip(a.status.label, a.status.color),
                );

            Widget? preventionCard() {
              final p = prevention;
              if (p == null) return null;
              final String title;
              final String subtitle;
              if (p.scheduled) {
                title = 'Retorno de prevenção: consulta já marcada';
                subtitle = 'Última consulta em ${f.date(p.lastVisit)}.';
              } else if (p.isDue) {
                title = 'Hora do seu retorno de prevenção';
                subtitle = 'Venceu em ${f.date(p.dueDate)} (6 meses após a consulta de '
                    '${f.date(p.lastVisit)}). Fale com a clínica para agendar.';
              } else {
                title = 'Retorno de prevenção em ${f.date(p.dueDate)}';
                subtitle = 'Faltam ${p.daysLeft} dia(s). Contado 6 meses após a consulta de '
                    '${f.date(p.lastVisit)}.';
              }
              return NoticeCard(
                icon: Icons.health_and_safety_outlined,
                color: Colors.teal,
                highlight: p.isDue && !p.scheduled,
                title: title,
                subtitle: subtitle,
              );
            }

            final pc = preventionCard();
            return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              if (pc != null) ...[const SectionTitle('Prevenção'), pc],
              const SectionTitle('Próximas'),
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Nenhuma consulta marcada. Para agendar, fale com a clínica.'),
                )
              else
                ...upcoming.map(tile),
              const SectionTitle('Dias de atendimento da clínica'),
              if (d.clinicDays.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('A clínica ainda não registrou os próximos dias de atendimento.'),
                )
              else
                for (final c in d.clinicDays)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Text('${c.day.day}', style: TextStyle(color: scheme.onPrimaryContainer)),
                    ),
                    title: Text(f.dayLong(c.day)),
                    subtitle: Text([
                      'Das ${c.startTime} às ${c.endTime}',
                      if (c.breakStart != null) 'pausa ${c.breakStart}–${c.breakEnd}',
                      if (several) companyName(c.companyId),
                      if (c.notes != null && c.notes!.isNotEmpty) c.notes!,
                    ].join(' · ')),
                  ),
              if (past.isNotEmpty) ...[
                const SectionTitle('Histórico'),
                ...past.map(tile),
              ],
            ]);
          },
        ),
      ),
    );
  }
}
