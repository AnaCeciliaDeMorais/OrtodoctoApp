import 'package:supabase_flutter/supabase_flutter.dart';

class UserManagementRepository {
  UserManagementRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Create a new user in Supabase Auth
  /// Returns the user UID if successful
  Future<String> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    try {
      // Create user in Supabase Auth
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Falha ao criar usuário no Auth');
      }

      final userId = authResponse.user!.id;

      // Create corresponding profile record
      await _client.from('profiles').insert({
        'id': userId,
        'nome': name,
        'email': email,
        'telefone': phone,
        'profile_level': role,
        'created_at': DateTime.now().toIso8601String(),
      });

      return userId;
    } catch (e) {
      throw Exception('Erro ao criar usuário: $e');
    }
  }

  /// Create a new patient/client
  Future<void> createPatientWithAuth({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? cpf,
    String? guardianName,
    String? guardianCpf,
  }) async {
    try {
      // Create user in Supabase Auth
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Falha ao criar usuário no Auth');
      }

      final userId = authResponse.user!.id;

      // Create patient record with auth association
      await _client.from('patients').insert({
        'id': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'cpf': cpf,
        'guardian_name': guardianName,
        'guardian_cpf': guardianCpf,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create profile record for login verification
      await _client.from('profiles').insert({
        'id': userId,
        'nome': name,
        'email': email,
        'telefone': phone,
        'profile_level': 'client',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erro ao criar cliente com acesso: $e');
    }
  }

  /// Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Generate a temporary password
  static String generateTemporaryPassword({int length = 12}) {
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789!@#\$%';
    final random = DateTime.now().microsecond;
    String password = '';
    for (int i = 0; i < length; i++) {
      password += chars[(random + i) % chars.length];
    }
    return password;
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? phone,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['nome'] = name;
    if (phone != null) updates['telefone'] = phone;

    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', userId);
  }

  /// Delete user (soft delete - deactivate)
  Future<void> deactivateUser(String userId) async {
    await _client
        .from('profiles')
        .update({'is_active': false})
        .eq('id', userId);
  }
}
