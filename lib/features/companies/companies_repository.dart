import '../../core/formatters.dart';
import '../../core/functions.dart';
import '../../core/supabase.dart';
import '../../shared/models/models.dart';

class CompaniesRepository {
  Future<Company> save(String? id, Map<String, dynamic> data) async {
    final row = id == null
        ? await sb.from('companies').insert({...data, 'owner_id': currentUserId}).select().single()
        : await sb.from('companies').update(data).eq('id', id).select().single();
    return Company.fromMap(row);
  }

  Future<void> delete(String id) => sb.from('companies').delete().eq('id', id);

  Future<List<Profile>> staff(String companyId) async {
    final rows = await sb
        .from('profiles')
        .select()
        .eq('company_id', companyId)
        .eq('role', 'staff')
        .order('full_name', ascending: true);
    return rows.map(Profile.fromMap).toList();
  }

  Future<void> createStaff({
    required String companyId,
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) =>
      callFunction('admin-users', {
        'action': 'create_staff',
        'company_id': companyId,
        'full_name': fullName,
        'email': email,
        'password': password,
        'phone': phone,
      });

  Future<void> updateStaff(String id, {String? fullName, String? phone, bool? active, String? companyId}) =>
      sb.from('profiles').update({
        'full_name': ?fullName,
        'phone': ?phone,
        'active': ?active,
        'company_id': ?companyId,
      }).eq('id', id);

  /// RN.6: só o chefe exclui funcionário (remove o login).
  Future<void> deleteStaff(String id) =>
      callFunction('admin-users', {'action': 'delete_staff', 'user_id': id});

  Future<List<ClinicDay>> clinicDays(String companyId, DateTime from, DateTime to) async {
    final rows = await sb
        .from('clinic_days')
        .select()
        .eq('company_id', companyId)
        .gte('day', isoDate(from))
        .lte('day', isoDate(to))
        .order('day', ascending: true);
    return rows.map(ClinicDay.fromMap).toList();
  }

  Future<void> saveClinicDays({
    required String companyId,
    required List<DateTime> days,
    required String start,
    required String end,
    String? breakStart,
    String? breakEnd,
    String? notes,
  }) =>
      sb.from('clinic_days').upsert([
        for (final d in days)
          {
            'company_id': companyId,
            'day': isoDate(d),
            'start_time': start,
            'end_time': end,
            'break_start': breakStart,
            'break_end': breakEnd,
            'notes': notes,
          }
      ], onConflict: 'company_id,day');

  Future<void> deleteClinicDay(String id) => sb.from('clinic_days').delete().eq('id', id);
}
