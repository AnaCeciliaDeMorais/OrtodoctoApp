import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../schedule/schedule_repository.dart';

/// Consultas do cliente (RN.9). Agendar é feito pela clínica (RN.11).
class ClientAppointmentsPage extends StatelessWidget {
  const ClientAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final several = SessionScope.of(context).companies.length > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas consultas')),
      body: ContentWidth(
        child: AsyncLoader<List<Appointment>>(
          load: () => ScheduleRepository().mine(),
          builder: (context, items, _) {
            final now = DateTime.now();
            final upcoming = items.where((a) => a.startsAt.isAfter(now) && a.isActive).toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
            final past = items.where((a) => !upcoming.contains(a)).toList();
            Widget tile(Appointment a) => ListTile(
                  leading: Icon(Icons.event, color: a.status.color),
                  title: Text(f.dateTime(a.startsAt)),
                  subtitle: Text([
                    if (a.label != null) a.label!,
                    if (several && a.companyName != null) a.companyName!,
                  ].join(' · ')),
                  trailing: StatusChip(a.status.label, a.status.color),
                );
            return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              const SectionTitle('Próximas'),
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Nenhuma consulta marcada. Para agendar, fale com a clínica.'),
                )
              else
                ...upcoming.map(tile),
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
