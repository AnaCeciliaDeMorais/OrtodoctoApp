import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/appointment_label_model.dart';
import '../models/appointment_model.dart';
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
        .select('*, patients(name)')
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

  Future<AppointmentLabelModel> createLabel(String name) async {
    final response = await _client
        .from('appointment_labels')
        .insert({'name': name})
        .select()
        .single();

    return AppointmentLabelModel.fromMap(response);
  }

  Future<void> createAppointment({
    required String patientId,
    required DateTime clinicDate,
    required String timeSlot,
    required String status,
    String? labelId,
    String? notes,
  }) async {
    final userId = currentUser!.id;
    final dateOnly = clinicDate.toIso8601String().split('T').first;

    await _client.from('appointments').insert({
      'patient_id': patientId,
      'clinic_date': dateOnly,
      'time_slot': timeSlot,
      'status': status,
      'label_id': labelId,
      'notes': notes,
      'blocked': false,
      'created_by': userId,
      'updated_by': userId,
    });
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

    await _client.from('appointments').update({
      'patient_id': patientId,
      'clinic_date': dateOnly,
      'time_slot': timeSlot,
      'status': status,
      'label_id': labelId,
      'notes': notes,
      'updated_by': userId,
    }).eq('id', appointmentId);
  }
}