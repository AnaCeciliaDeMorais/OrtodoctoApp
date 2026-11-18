import '../../core/formatters.dart';
import '../../core/supabase.dart';
import '../../shared/models/models.dart';

class CashRepository {
  static const _select =
      '*, profiles!cash_entries_staff_id_fkey(full_name), companies(name), patients(full_name)';

  /// [companyIds] vazio = todas que o usuário enxerga; [staffId] null = todos.
  Future<List<CashEntry>> list({
    required List<String> companyIds,
    String? staffId,
    required DateTime from,
    required DateTime to,
  }) async {
    var q = sb.from('cash_entries').select(_select).gte('occurred_on', isoDate(from)).lte('occurred_on', isoDate(to));
    if (companyIds.isNotEmpty) q = q.inFilter('company_id', companyIds);
    if (staffId != null) q = q.eq('staff_id', staffId);
    final rows = await q.order('occurred_on', ascending: false).order('created_at', ascending: false);
    return rows.map(CashEntry.fromMap).toList();
  }

  /// Pessoas com caixa nas empresas (funcionários + chefe).
  Future<List<Profile>> people(List<String> companyIds) async {
    final rows = await sb.from('profiles').select().inFilter('company_id', companyIds).order('full_name', ascending: true);
    final me = await sb.from('profiles').select().eq('id', currentUserId!).single();
    return [Profile.fromMap(me), ...rows.map(Profile.fromMap)];
  }

  Future<void> save({
    String? id,
    required String companyId,
    required CashKind kind,
    required double amount,
    required String description,
    String? method,
    required DateTime date,
  }) async {
    final data = {
      'company_id': companyId,
      'kind': kind == CashKind.in_ ? 'in' : 'out',
      'amount': amount,
      'description': description,
      'payment_method': method,
      'occurred_on': isoDate(date),
    };
    if (id == null) {
      await sb.from('cash_entries').insert({...data, 'staff_id': currentUserId});
    } else {
      await sb.from('cash_entries').update(data).eq('id', id);
    }
  }

  Future<void> delete(String id) => sb.from('cash_entries').delete().eq('id', id);
}
