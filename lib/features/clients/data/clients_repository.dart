import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/client_model.dart';

class ClientsRepository {
  ClientsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ClientModel>> getClientsOrderedByName() async {
    final response = await _client
        .from('patients')
        .select()
        .order('name', ascending: true);

    return (response as List)
        .map((e) => ClientModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<ClientModel> getClientById(String clientId) async {
    final response = await _client
        .from('patients')
        .select()
        .eq('id', clientId)
        .single();

    return ClientModel.fromMap(response);
  }

  Future<void> updateClient({
    required String clientId,
    required String name,
    String? rg,
    String? cpf,
    String? phone,
    String? addressStreet,
    String? addressNumber,
    String? neighborhood,
    String? city,
    DateTime? birthDate,
    String? guardianName,
  }) async {
    await _client.from('patients').update({
      'name': name,
      'rg': rg,
      'cpf': cpf,
      'phone': phone,
      'address_street': addressStreet,
      'address_number': addressNumber,
      'neighborhood': neighborhood,
      'city': city,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'guardian_name': guardianName,
    }).eq('id', clientId);
  }

  Future<void> deleteClient(String clientId) async {
    await _client.from('patients').delete().eq('id', clientId);
  }
}