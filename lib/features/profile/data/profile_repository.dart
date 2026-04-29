import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cash_entry_model.dart';
import '../models/profile_employee_model.dart';
import '../models/treatment_item_model.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<ProfileEmployeeModel> getMyProfile() async {
    final userId = currentUser!.id;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return ProfileEmployeeModel.fromMap(response);
  }

  Future<List<CashEntryModel>> getMyCashEntries() async {
    final userId = currentUser!.id;

    final response = await _client
        .from('cash_entries')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => CashEntryModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TreatmentItemModel>> getMyTreatments() async {
    final userId = currentUser!.id;

    final response = await _client
        .from('treatments')
        .select()
        .eq('created_by', userId)
        .eq('is_active', true)
        .order('is_promotion', ascending: false)
        .order('title', ascending: true);

    return (response as List)
        .map((e) => TreatmentItemModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> insertCashEntry({
    required String status,
    required double value,
    required DateTime paymentDate,
    required String reason,
    required String paymentMethod,
  }) async {
    final userId = currentUser!.id;

    await _client.from('cash_entries').insert({
      'created_by': userId,
      'status': status,
      'value': value,
      'payment_date': paymentDate.toIso8601String().split('T').first,
      'observation': reason,
      'payment_method': paymentMethod,
    });
  }

  Future<void> insertTreatment({
    required String title,
    required String? description,
    required bool isPromotion,
  }) async {
    final userId = currentUser!.id;

    await _client.from('treatments').insert({
      'created_by': userId,
      'title': title,
      'description': description,
      'is_promotion': isPromotion,
      'is_active': true,
    });
  }

  Future<void> deleteTreatment(String treatmentId) async {
    await _client.from('treatments').delete().eq('id', treatmentId);
  }

  Future<void> deleteCashEntry(String entryId) async {
    await _client.from('cash_entries').delete().eq('id', entryId);
  }
}