import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment_label_model.dart';
import '../models/appointment_model.dart';
import '../models/appointment_reminder_model.dart';
import '../models/clinic_day_model.dart';

class SchedulingRepository {
  SchedulingRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<List<AppointmentModel>> getAppointmentsByDate(DateTime date) async {
    final dateOnly = date.toIso8601String().split('T').first;

    final response = await _client
        .from('appointments')
        .select('''
          *,
          patients(name),
          appointment_reminders(*)
        ''')
        .eq('clinic_date', dateOnly)
        .order('time_slot', ascending: true);

    return (response as List)
        .map((e) => AppointmentModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClinicDayModel>> getAvailableClinicDays() async {
    final response = await _client
        .from('clinic_days')
        .select()
        .order('clinic_date', ascending: true);

    return (response as List)
        .map((e) => ClinicDayModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppointmentLabelModel>> getLabels() async {
    final response = await _client
        .from('appointment_labels')
        .select()
        .order('name', ascending: true);

    return (response as List)
        .map((e) => AppointmentLabelModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createAppointment({
    required String patientId,
    required DateTime clinicDate,
    required String timeSlot,
    required String status,
    String? labelId,
    String? customLabel,
    String? notes,
    required List<AppointmentReminderModel> reminders,
  }) async {
    final userId = currentUser!.id;
    final dateOnly = clinicDate.toIso8601String().split('T').first;

    final existing = await _client
        .from('appointments')
        .select('id')
        .eq('clinic_date', dateOnly)
        .eq('time_slot', timeSlot)
        .eq('blocked', false);

    if ((existing as List).isNotEmpty) {
      throw Exception('Já existe um agendamento neste horário.');
    }

    final inserted = await _client
        .from('appointments')
        .insert({
          'patient_id': patientId,
          'clinic_date': dateOnly,
          'time_slot': timeSlot,
          'status': status,
          'label_id': labelId,
          'custom_label': customLabel,
          'notes': notes,
          'blocked': false,
          'created_by': userId,
          'updated_by': userId,
        })
        .select()
        .single();

    final appointmentId = inserted['id'] as String;

    if (reminders.isNotEmpty) {
      await _client.from('appointment_reminders').insert(
            reminders
                .map(
                  (r) => {
                    'appointment_id': appointmentId,
                    'reminder_text': r.reminderText,
                    'show_on_date':
                        r.showOnDate.toIso8601String().split('T').first,
                    'created_by': userId,
                  },
                )
                .toList(),
          );
    }
  }

  Future<void> updateAppointment({
    required String appointmentId,
    required String patientId,
    required DateTime clinicDate,
    required String timeSlot,
    required String status,
    String? labelId,
    String? customLabel,
    String? notes,
    required List<AppointmentReminderModel> reminders,
  }) async {
    final userId = currentUser!.id;
    final dateOnly = clinicDate.toIso8601String().split('T').first;

    final existing = await _client
        .from('appointments')
        .select('id')
        .eq('clinic_date', dateOnly)
        .eq('time_slot', timeSlot)
        .neq('id', appointmentId)
        .eq('blocked', false);

    if ((existing as List).isNotEmpty) {
      throw Exception('Já existe outro agendamento neste horário.');
    }

    await _client.from('appointments').update({
      'patient_id': patientId,
      'clinic_date': dateOnly,
      'time_slot': timeSlot,
      'status': status,
      'label_id': labelId,
      'custom_label': customLabel,
      'notes': notes,
      'updated_by': userId,
    }).eq('id', appointmentId);

    await _client
        .from('appointment_reminders')
        .delete()
        .eq('appointment_id', appointmentId);

    if (reminders.isNotEmpty) {
      await _client.from('appointment_reminders').insert(
            reminders
                .map(
                  (r) => {
                    'appointment_id': appointmentId,
                    'reminder_text': r.reminderText,
                    'show_on_date':
                        r.showOnDate.toIso8601String().split('T').first,
                    'created_by': userId,
                  },
                )
                .toList(),
          );
    }
  }

  Future<void> deleteAppointment({
    required String appointmentId,
    required String reason,
  }) async {
    final userId = currentUser!.id;

    await _client.from('appointments').update({
      'deleted_reason': reason,
      'updated_by': userId,
    }).eq('id', appointmentId);

    await _client.from('appointment_reminders')
        .delete()
        .eq('appointment_id', appointmentId);

    await _client.from('appointments').delete().eq('id', appointmentId);
  }
}