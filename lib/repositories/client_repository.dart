import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/models/client_model.dart';

class ClientRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getPatients() async {
    final response = await _supabase
        .from('patients')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deletePatient(String id) async {
  await _supabase
      .from('patients')
      .delete()
      .eq('id', id);
}

  Future<ClientModel> getClientById(String id) async {
    final response =
        await _supabase.from('patients').select().eq('id', id).single();

    return ClientModel.fromMap(response);
  }

  Future<void> createPatient({
    required String name,
    String? phone,
    String? cpf,
    String? guardianName,
    String? guardianCpf,
  }) async {
    await _supabase.from('patients').insert({
      'name': name,
      'phone': phone,
      'cpf': cpf,
      'guardian_name': guardianName,
      'guardian_cpf': guardianCpf,
    });
  }

 Future<void> updatePatient({
  required String id,
  required String name,
  String? phone,
  String? cpf,
  String? rg,
  String? addressStreet,
  String? addressNumber,
  String? neighborhood,
  String? city,
  String? guardianName,
  String? guardianCpf,
}) async {
  await _supabase.from('patients').update({
    'name': name,
    'phone': phone,
    'cpf': cpf,
    'rg': rg,
    'street': addressStreet,
    'number': addressNumber,
    'neighborhood': neighborhood,
    'city': city,
    'guardian_name': guardianName,
    'guardian_cpf': guardianCpf,
  }).eq('id', id);
}

Future<List<Map<String, dynamic>>> getClientFinancialEntries(
  String clientId,
) async {
  final response = await _supabase
      .from('cash_entries')
      .select()
      .eq('patient_id', clientId)
      .order('due_date', ascending: false);

  return List<Map<String, dynamic>>.from(response);
}

Future<void> createFinancialEntry({
  required String clientId,
  required String status,
  required double value,
  required DateTime dueDate,
  String? description,
  String entryType = 'launch',
  String? installmentGroupId,
  int? installmentNumber,
  int? installmentTotal,
}) async {

  final userId = _supabase.auth.currentUser?.id;

  await _supabase.from('cash_entries').insert({
    'patient_id': clientId,
    'created_by': userId,
    'status': 'x',
    'value': value,
    'due_date': dueDate.toIso8601String(),
    'description': description,
    'confirmed': false,
    'entry_type': entryType,
    'installment_group_id': installmentGroupId,
    'installment_number': installmentNumber,
    'installment_total': installmentTotal,
  });
}
  Future<void> updateFinancialEntry({
    required String id,
    required String status,
    required double value,
    required DateTime dueDate,
    String? description,
  }) async {
    await _supabase.from('cash_entries').update({
      'status': status,
      'value': value,
      'due_date': dueDate.toIso8601String(),
      'description': description,
      'confirmed': status == 'ok',
    }).eq('id', id);
  }

  Future<void> deleteFinancialEntry(String id) async {
    await _supabase.from('cash_entries').delete().eq('id', id);
  }

  Future<void> confirmPayment({
    required String id,
    required String paymentMethod,
  }) async {
    await _supabase.from('cash_entries').update({
      'status': 'ok',
      'confirmed': true,
      'payment_method': paymentMethod,
      'payment_date': DateTime.now().toIso8601String(),
      'confirmed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getClientAppointments(
  String clientId,
  ) async {
     final response = await _supabase
          .from('appointments')
          .select('''
            id,
            clinic_date,
            time_slot,
            status,
            attendance_status,
            custom_label,
            notes,
            appointment_labels(name)
          ''')
          .eq('patient_id', clientId)
          .order('clinic_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
} 
}