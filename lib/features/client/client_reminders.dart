import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/formatters.dart' as f;
import '../../shared/models/models.dart';

/// Regras dos avisos do paciente, usadas no Início, em Consultas e no alerta
/// que aparece 1 hora antes da consulta.

/// Intervalo do retorno de prevenção, contado a partir da última consulta.
const preventionMonths = 6;

/// Consultas ainda por acontecer (agendadas ou confirmadas), da mais próxima
/// para a mais distante.
List<Appointment> upcomingAppointments(List<Appointment> items, [DateTime? now]) {
  final n = now ?? DateTime.now();
  return items
      .where((a) =>
          a.startsAt.isAfter(n) &&
          (a.status == AppointmentStatus.scheduled || a.status == AppointmentStatus.confirmed))
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}

/// Consultas que começam dentro da próxima hora.
List<Appointment> startingWithinAnHour(List<Appointment> items, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final limit = n.add(const Duration(hours: 1));
  return upcomingAppointments(items, n).where((a) => !a.startsAt.isAfter(limit)).toList();
}

/// Última consulta realizada (status "Atendido").
Appointment? lastDoneAppointment(List<Appointment> items) {
  final now = DateTime.now();
  Appointment? last;
  for (final a in items) {
    if (a.status != AppointmentStatus.done || a.startsAt.isAfter(now)) continue;
    if (last == null || a.startsAt.isAfter(last.startsAt)) last = a;
  }
  return last;
}

/// Soma meses sem estourar o fim do mês (31/08 + 6 meses = 28/02).
DateTime addMonths(DateTime d, int months) {
  final y = d.year + (d.month - 1 + months) ~/ 12;
  final m = (d.month - 1 + months) % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
}

class PreventionReturn {
  PreventionReturn(this.lastVisit, this.dueDate, this.scheduled);

  /// Dia da última consulta realizada.
  final DateTime lastVisit;

  /// Dia em que vence o retorno (6 meses depois da última consulta).
  final DateTime dueDate;

  /// Já existe consulta marcada depois da última realizada.
  final bool scheduled;

  int get daysLeft => dueDate.difference(f.dayOnly(DateTime.now())).inDays;
  bool get isDue => daysLeft <= 0;
}

PreventionReturn? preventionReturn(List<Appointment> items) {
  final last = lastDoneAppointment(items);
  if (last == null) return null;
  final day = f.dayOnly(last.startsAt);
  return PreventionReturn(
    day,
    addMonths(day, preventionMonths),
    upcomingAppointments(items).isNotEmpty,
  );
}

/// Fichas cujo aniversário é hoje (29/02 comemora em 28/02 nos anos comuns).
List<Patient> birthdayToday(List<Patient> patients, [DateTime? now]) {
  final n = now ?? DateTime.now();
  bool isToday(DateTime b) {
    if (b.month == n.month && b.day == n.day) return true;
    final leap = DateTime(n.year, 3, 0).day == 29;
    return !leap && b.month == 2 && b.day == 29 && n.month == 2 && n.day == 28;
  }

  final seen = <String>{};
  return patients.where((p) => p.birthDate != null && isToday(p.birthDate!) && seen.add(p.fullName)).toList();
}

String minutesUntil(DateTime start) {
  final m = start.difference(DateTime.now()).inMinutes;
  if (m <= 0) return 'agora';
  if (m == 1) return 'em 1 minuto';
  if (m >= 60) return 'em 1 hora';
  return 'em $m minutos';
}

/// Cartão de aviso usado no Início e em Consultas.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.highlight = false,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        color: highlight ? color.withValues(alpha: 0.10) : null,
        child: ListTile(
          leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
          title: Text(title, style: highlight ? const TextStyle(fontWeight: FontWeight.w600) : null),
          subtitle: Text(subtitle),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

/// Fica em volta da área logada do cliente. Enquanto o app está aberto,
/// confere a cada 30 segundos se alguma consulta começa dentro de 1 hora e
/// mostra um alerta uma única vez por consulta.
class AppointmentAlertWatcher extends StatefulWidget {
  const AppointmentAlertWatcher({super.key, required this.load, required this.child});

  /// Busca as consultas do cliente.
  final Future<List<Appointment>> Function() load;
  final Widget child;

  @override
  State<AppointmentAlertWatcher> createState() => _AppointmentAlertWatcherState();
}

class _AppointmentAlertWatcherState extends State<AppointmentAlertWatcher> {
  static const _refreshEvery = Duration(minutes: 10);
  final _alerted = <String>{};
  List<Appointment> _items = [];
  DateTime? _loadedAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final now = DateTime.now();
    if (_loadedAt == null || now.difference(_loadedAt!) >= _refreshEvery) {
      try {
        _items = await widget.load();
        _loadedAt = now;
      } catch (_) {
        return; // sem internet: tenta de novo na próxima volta
      }
    }
    if (!mounted) return;
    for (final a in startingWithinAnHour(_items)) {
      if (!_alerted.add(a.id)) continue;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        duration: const Duration(seconds: 15),
        showCloseIcon: true,
        content: Row(children: [
          const Icon(Icons.alarm, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Lembrete: sua consulta começa ${minutesUntil(a.startsAt)}, '
                'às ${f.time(a.startsAt)}.'),
          ),
        ]),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
