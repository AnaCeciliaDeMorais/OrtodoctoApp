import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/treatment_model.dart';

class TreatmentsRepository {
  TreatmentsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<TreatmentModel>> getTreatments() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final response = await _client
        .from('treatments')
        .select()
        .eq('created_by', userId)
        .eq('is_active', true)
        .order('is_promotion', ascending: false)
        .order('title', ascending: true);

    return (response as List)
        .map((e) => TreatmentModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<TreatmentModel> createTreatment({
    required String title,
    String? description,
    double? originalPrice,
    double? promotionalPrice,
    required bool isPromotion,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuário não autenticado');

    final treatmentData = {
      'title': title,
      'description': description,
      'original_price': originalPrice,
      'promotional_price': promotionalPrice,
      'is_promotion': isPromotion,
      'is_active': true,
      'created_by': userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('treatments')
        .insert(treatmentData)
        .select()
        .single();

    return TreatmentModel.fromMap(response);
  }

  Future<void> updateTreatment({
    required String treatmentId,
    required String title,
    String? description,
    double? originalPrice,
    double? promotionalPrice,
    required bool isPromotion,
  }) async {
    final treatmentData = {
      'title': title,
      'description': description,
      'original_price': originalPrice,
      'promotional_price': promotionalPrice,
      'is_promotion': isPromotion,
    };

    await _client
        .from('treatments')
        .update(treatmentData)
        .eq('id', treatmentId);
  }

  Future<void> deleteTreatment(String treatmentId) async {
    await _client
        .from('treatments')
        .update({'is_active': false})
        .eq('id', treatmentId);
  }
}