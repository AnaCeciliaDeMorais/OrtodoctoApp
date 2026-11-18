import '../../core/formatters.dart';
import '../../core/supabase.dart';
import '../../shared/models/models.dart';

const _select = '*, patients(full_name, phone), companies(name)';

class ScheduleRepository {
  Future<List<Appointment>> range(String companyId, DateTime from, DateTime to) async {
    final rows = await sb
        .from('appointments')
        .select(_select)
        .eq('company_id', companyId)
        .gte('starts_at', from.toUtc().toIso8601String())
        .lt('starts_at', to.toUtc().toIso8601String())
        .order('starts_at', ascending: true);
    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<Appointment>> forPatient(String patientId) async {
    final rows = await sb
        .from('appointments')
        .select(_select)
        .eq('patient_id', patientId)
        .order('starts_at', ascending: false);
    return rows.map(Appointment.fromMap).toList();
  }

  /// Cliente logado: os próprios agendamentos (o RLS já filtra).
  Future<List<Appointment>> mine() async {
    final rows = await sb.from('appointments').select(_select).order('starts_at', ascending: false);
    return rows.map(Appointment.fromMap).toList();
  }

  Future<void> save({
    String? id,
    required String companyId,
    required String patientId,
    required DateTime startsAt,
    required int duration,
    required AppointmentStatus status,
    String? label,
    String? notes,
  }) async {
    final data = {
      'company_id': companyId,
      'patient_id': patientId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'duration_minutes': duration,
      'status': status.name,
      'label': label,
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
    };
    if (id == null) {
      await sb.from('appointments').insert(data);
    } else {
      await sb.from('appointments').update(data).eq('id', id);
    }
  }

  Future<void> setStatus(String id, AppointmentStatus status) =>
      sb.from('appointments').update({'status': status.name}).eq('id', id);

  Future<void> delete(String id) => sb.from('appointments').delete().eq('id', id);

  Future<List<ClinicDay>> clinicDays(String companyId, DateTime from, DateTime to) async {
    final rows = await sb
        .from('clinic_days')
        .select()
        .eq('company_id', companyId)
        .gte('day', isoDate(from))
        .lte('day', isoDate(to));
    return rows.map(ClinicDay.fromMap).toList();
  }
}

/// Horários de um dia de atendimento.
/// [day] é o dia cadastrado pelo chefe; sem ele usa o horário padrão da empresa.
List<DateTime> slotsFor(DateTime date, Company company, ClinicDay? day) {
  final start = minutesOf(day?.startTime ?? company.openingTime);
  final end = minutesOf(day?.endTime ?? company.closingTime);
  final bStart = day?.breakStart == null ? null : minutesOf(day!.breakStart!);
  final bEnd = day?.breakEnd == null ? null : minutesOf(day!.breakEnd!);
  final out = <DateTime>[];
  for (var m = start; m + company.slotMinutes <= end; m += company.slotMinutes) {
    if (bStart != null && bEnd != null && m < bEnd && m + company.slotMinutes > bStart) continue;
    out.add(DateTime(date.year, date.month, date.day, m ~/ 60, m % 60));
  }
  return out;
}

int minutesOf(String hhmm) {
  final t = parseTime(hhmm);
  return t.h * 60 + t.m;
}
