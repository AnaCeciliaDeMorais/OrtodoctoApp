import '../../core/functions.dart';
import '../../core/supabase.dart';
import '../../shared/models/models.dart';

class PatientsRepository {
  Future<List<Patient>> list(String companyId, {String query = ''}) async {
    var q = sb.from('patients').select().eq('company_id', companyId);
    final term = query.trim().replaceAll(RegExp(r'[,()%]'), ' ');
    if (term.isNotEmpty) {
      final digits = term.replaceAll(RegExp(r'\D'), '');
      q = q.or([
        'full_name.ilike.%$term%',
        if (digits.length >= 3) 'cpf.ilike.%$digits%',
        if (digits.length >= 3) 'phone.ilike.%$digits%',
      ].join(','));
    }
    final rows = await q.order('full_name', ascending: true).limit(500);
    return rows.map(Patient.fromMap).toList();
  }

  Future<Patient> get(String id) async =>
      Patient.fromMap(await sb.from('patients').select().eq('id', id).single());

  Future<Patient> save(String? id, Patient p) async {
    final row = id == null
        ? await sb.from('patients').insert(p.toMap()).select().single()
        : await sb.from('patients').update(p.toMap()..remove('company_id')).eq('id', id).select().single();
    return Patient.fromMap(row);
  }

  Future<void> delete(Patient p) async {
    if (p.hasAccess) await removeAccess(p.id);
    await sb.from('patients').delete().eq('id', p.id);
  }

  /// Cria (ou reaproveita) o login do cliente e liga à ficha.
  Future<void> createAccess(String patientId, String email, String password) =>
      callFunction('admin-users', {
        'action': 'create_client_access',
        'patient_id': patientId,
        'email': email,
        'password': password,
      });

  Future<void> removeAccess(String patientId) =>
      callFunction('admin-users', {'action': 'remove_client_access', 'patient_id': patientId});
}

class ChargesRepository {
  static const _select =
      '*, receiver:profiles!charges_received_by_fkey(full_name), approver:profiles!charges_approved_by_fkey(full_name)';

  Future<List<Charge>> forPatient(String patientId) async {
    final rows = await sb.from('charges').select(_select).eq('patient_id', patientId).order('due_date', ascending: true);
    return rows.map(Charge.fromMap).toList();
  }

  /// Cliente logado: todas as cobranças dele (o RLS já filtra).
  Future<List<Charge>> mine() async {
    final rows = await sb.from('charges').select('*, companies(name)').order('due_date', ascending: true);
    return rows.map(Charge.fromMap).toList();
  }

  /// Chefe: pagamentos recebidos pela equipe aguardando aprovação.
  Future<List<Charge>> pendingApproval(String? companyId) async {
    var q = sb
        .from('charges')
        .select('$_select, patients(full_name), companies(name)')
        .eq('status', 'paid')
        .isFilter('approved_by', null);
    if (companyId != null) q = q.eq('company_id', companyId);
    final rows = await q.order('paid_at', ascending: false);
    return rows.map(Charge.fromMap).toList();
  }

  Future<void> createInstallments({
    required String patientId,
    required String description,
    required double total,
    required int count,
    required DateTime firstDue,
  }) =>
      sb.rpc('create_installments', params: {
        'p_patient_id': patientId,
        'p_description': description,
        'p_total': total,
        'p_count': count,
        'p_first_due': firstDue.toIso8601String().substring(0, 10),
      });

  Future<void> update(String id, {required String description, required double amount, required DateTime due}) =>
      sb.from('charges').update({
        'description': description,
        'amount': amount,
        'due_date': due.toIso8601String().substring(0, 10),
      }).eq('id', id);

  Future<void> cancel(String id) => sb.from('charges').update({'status': 'canceled'}).eq('id', id);

  Future<void> reopen(String id) => sb.from('charges').update({'status': 'open'}).eq('id', id);

  Future<void> delete(String id) => sb.from('charges').delete().eq('id', id);

  Future<void> pay(String id, String method, DateTime paidOn) => sb.rpc('pay_charge', params: {
        'p_charge_id': id,
        'p_method': method,
        'p_paid_on': paidOn.toIso8601String().substring(0, 10),
      });

  Future<void> reverse(String id) => sb.rpc('reverse_charge', params: {'p_charge_id': id});

  Future<void> approve(String id) => sb.rpc('approve_charge', params: {'p_charge_id': id});

  Future<void> createBoleto(String id) =>
      callFunction('asaas', {'action': 'create', 'charge_id': id});

  Future<void> cancelBoleto(String id) =>
      callFunction('asaas', {'action': 'cancel', 'charge_id': id});
}
