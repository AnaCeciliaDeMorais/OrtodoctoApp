import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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
    await PatientFilesRepository().removeAllOf(p.id);
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
      '*, receiver:profiles!charges_received_by_fkey(full_name), approver:profiles!charges_approved_by_fkey(full_name), patient_files(*), charge_payments(*)';

  Future<List<Charge>> forPatient(String patientId) async {
    final rows = await sb.from('charges').select(_select).eq('patient_id', patientId).order('due_date', ascending: true);
    return rows.map(Charge.fromMap).toList();
  }

  /// Cliente logado: todas as cobranças dele (o RLS já filtra).
  Future<List<Charge>> mine() async {
    final rows = await sb.from('charges').select('*, companies(name), patient_files(*), charge_payments(*)').order('due_date', ascending: true);
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

  /// Recebe um ou mais pagamentos (várias formas e/ou parcial). Cada parte
  /// vira uma entrada no caixa de quem recebeu. [interest] = juros/multa.
  Future<void> receivePayment(
    String id, {
    required List<PaymentPart> parts,
    required DateTime paidOn,
    double interest = 0,
  }) =>
      sb.rpc('receive_payment', params: {
        'p_charge_id': id,
        'p_parts': [for (final p in parts) p.toMap()],
        'p_paid_on': paidOn.toIso8601String().substring(0, 10),
        'p_interest': interest,
      });

  Future<void> reverse(String id) => sb.rpc('reverse_charge', params: {'p_charge_id': id});

  Future<void> approve(String id) => sb.rpc('approve_charge', params: {'p_charge_id': id});
}

/// Uma forma de pagamento usada ao dar baixa.
class PaymentPart {
  PaymentPart(this.method, this.amount, [this.installments = 1]);
  final String method;
  final double amount;
  final int installments;

  Map<String, dynamic> toMap() => {
        'method': method,
        'amount': amount,
        'installments': method == creditCardMethod ? installments : 1,
      };
}

/// Pasta do paciente no Storage (bucket privado): boletos e documentos.
/// Caminho: `empresa/paciente/arquivo`. O RLS libera a equipe da empresa
/// e o próprio paciente (só leitura).
class PatientFilesRepository {
  static const bucket = 'patient-files';
  static const allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  Future<List<PatientFile>> list(String patientId) async {
    final rows = await sb
        .from('patient_files')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return rows.map(PatientFile.fromMap).toList();
  }

  /// Cliente logado: todos os arquivos dele (o RLS já filtra).
  Future<List<PatientFile>> mine() async {
    final rows = await sb.from('patient_files').select().order('created_at', ascending: false);
    return rows.map(PatientFile.fromMap).toList();
  }

  Future<void> upload({
    required String companyId,
    required String patientId,
    required Uint8List bytes,
    required String fileName,
    required String title,
    String kind = 'boleto',
    String? chargeId,
    DateTime? dueDate,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final contentType = switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$companyId/$patientId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    await sb.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    try {
      await sb.from('patient_files').insert({
        'company_id': companyId,
        'patient_id': patientId,
        'charge_id': chargeId,
        'kind': kind,
        'title': title.trim(),
        'due_date': dueDate?.toIso8601String().substring(0, 10),
        'file_path': path,
        'file_name': fileName,
        'content_type': contentType,
        'size_bytes': bytes.length,
      });
    } catch (_) {
      await _removeObjects([path]);
      rethrow;
    }
  }

  Future<void> delete(PatientFile file) async {
    await sb.from('patient_files').delete().eq('id', file.id);
    await _removeObjects([file.filePath]);
  }

  /// Usado ao excluir a ficha do paciente.
  Future<void> removeAllOf(String patientId) async {
    final files = await list(patientId);
    if (files.isEmpty) return;
    await sb.from('patient_files').delete().eq('patient_id', patientId);
    await _removeObjects([for (final f in files) f.filePath]);
  }

  /// Link temporário (10 min) para abrir ou baixar o arquivo.
  Future<String> signedUrl(PatientFile file) =>
      sb.storage.from(bucket).createSignedUrl(file.filePath, 600);

  Future<void> _removeObjects(List<String> paths) async {
    try {
      await sb.storage.from(bucket).remove(paths);
    } catch (_) {
      // Arquivo órfão no Storage não aparece para ninguém (não tem registro).
    }
  }
}
