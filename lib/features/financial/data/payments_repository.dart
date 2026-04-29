import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/payment_model.dart';

class PaymentsRepository {
  PaymentsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<PaymentModel>> getPayments() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final response = await _client
        .from('cash_entries')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => PaymentModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentModel> createPayment({
    required double value,
    required String status,
    String? observation,
    String? paymentMethod,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuário não autenticado');

    final paymentData = {
      'value': value,
      'status': status,
      'observation': observation,
      'payment_method': paymentMethod,
      'created_by': userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('cash_entries')
        .insert(paymentData)
        .select()
        .single();

    return PaymentModel.fromMap(response);
  }

  Future<void> updatePayment({
    required String paymentId,
    required double value,
    required String status,
    String? observation,
    String? paymentMethod,
  }) async {
    final paymentData = {
      'value': value,
      'status': status,
      'observation': observation,
      'payment_method': paymentMethod,
    };

    await _client
        .from('cash_entries')
        .update(paymentData)
        .eq('id', paymentId);
  }

  Future<void> deletePayment(String paymentId) async {
    await _client.from('cash_entries').delete().eq('id', paymentId);
  }
}