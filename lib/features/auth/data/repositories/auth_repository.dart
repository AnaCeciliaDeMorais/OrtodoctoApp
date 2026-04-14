import '../../../../core/supabase/supabase_service.dart';
// searching for the role of the user in the database, to know if it's a staff or a patient
class AuthRepository {
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = SupabaseService.client.auth.currentUser;

    if (user == null) return null;

    final data = await SupabaseService.client
        .from('profiles')
        .select('id, nome, profile_level')
        .eq('id', user.id)
        .single();

    return data;
  }
}