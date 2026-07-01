import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment_label_model.dart';
import '../models/appointment_model.dart';
import '../models/appointment_reminder_model.dart';
import '../models/clinic_day_model.dart';

class SchedulingRepository {
  SchedulingRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<List<Map<String, dynamic>>> getPatients() async {
    final response = await _supabase
        .from('patients')
        .select('id, name')
        .order('name');

    final data = response as List?;
    if (data == null) return [];

    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<AppointmentReminderModel>> getReminders() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('appointment_reminders')
        .select()
        .eq('created_by', userId)
        .order('show_on_date', ascending: true);

    final data = response as List?;
    if (data == null) return [];

    return data
        .map((e) => AppointmentReminderModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppointmentReminderModel> createReminder({
    required String appointmentId,
    required String reminderText,
    required DateTime showOnDate,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    final reminderData = {
      'appointment_id': appointmentId,
      'reminder_text': reminderText,
      'show_on_date': showOnDate.toIso8601String().split('T').first,
      'created_by': userId,
    };

    final response = await _client
        .from('appointment_reminders')
        .insert(reminderData)
        .select()
        .single();

    return AppointmentReminderModel.fromMap(response);
  }

  Future<void> deleteReminder(String id) async {
    await _client.from('appointment_reminders').delete().eq('id', id);
  }

  Future<void> createAppointment({
    required String patientId,
    required DateTime clinicDate,
    required String timeSlot,
    String? labelId,
    String? notes,
    List<AppointmentReminderModel>? reminders,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final dateOnly = clinicDate.toIso8601String().split('T').first;

    final response = await _client
        .from('appointments')
        .insert({
          'patient_id': patientId,
          'clinic_date': dateOnly,
          'time_slot': timeSlot,
          'status': 'Agendado',
          'attendance_status': 'Agendado',
          'label_id': labelId,
          'notes': notes,
          'created_by': userId,
        })
        .select('id')
        .single();

    final appointmentId = response?['id']?.toString();
    if (appointmentId == null) {
      throw Exception('Falha ao criar agendamento: id não retornado');
    }

    if (reminders != null && reminders.isNotEmpty) {
      for (final reminder in reminders) {
        await _client.from('appointment_reminders').insert({
          'appointment_id': appointmentId,
          'reminder_text': reminder.reminderText,
          'show_on_date': reminder.showOnDate
              .toIso8601String()
              .split('T')
              .first,
          'created_by': userId,
        });
      }
    }
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _client.from('appointments').delete().eq('id', appointmentId);
  }

  Future<List<AppointmentModel>> getClientUpcomingAppointments() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final today = DateTime.now().toIso8601String().split('T').first;

    final response = await _client
        .from('appointments')
        .select('*, patients(name)')
        .eq('patient_id', userId)
        .gte('clinic_date', today)
        .order('clinic_date', ascending: true)
        .order('time_slot', ascending: true);

    final data = response as List?;
    if (data == null) return [];

    return data
        .map((e) => AppointmentModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppointmentModel>> getAppointmentsByDate(DateTime date) async {
    final dateOnly = date.toIso8601String().split('T').first;

    final response = await _client
        .from('appointments')
        .select('*, patients(name)')
        .eq('clinic_date', dateOnly)
        .order('time_slot', ascending: true);

    final data = response as List?;
    if (data == null) return [];

    return data
        .map((e) => AppointmentModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClinicDayModel>> getAvailableClinicDays() async {
    final response = await _client
        .from('clinic_days')
        .select()
        .order('clinic_date', ascending: true);

    final data = response as List?;
    if (data == null) return [];

    return data
        .map((e) => ClinicDayModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppointmentLabelModel>> getLabels() async {
    final response = await _client
        .from('appointment_labels')
        .select()
        .order('name', ascending: true);

    final data = response as List?;
    if (data == null) return [];

    return data
        .map((e) => AppointmentLabelModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppointmentLabelModel> createLabel(String name) async {
    final response = await _client
        .from('appointment_labels')
        .insert({'name': name})
        .select()
        .single();

    return AppointmentLabelModel.fromMap(response);
  }

  Future<void> updateAppointment({
    required String appointmentId,
    required String patientId,
    required DateTime clinicDate,
    required String timeSlot,
    required String status,
    String? labelId,
    String? notes,
  }) async {
    final userId = currentUser!.id;
    final dateOnly = clinicDate.toIso8601String().split('T').first;

    await _client
        .from('appointments')
        .update({
          'patient_id': patientId,
          'clinic_date': dateOnly,
          'time_slot': timeSlot,
          'status': status,
          'label_id': labelId,
          'notes': notes,
          'updated_by': userId,
          'attendance_status': status,
        })
        .eq('id', appointmentId);
  }
}
