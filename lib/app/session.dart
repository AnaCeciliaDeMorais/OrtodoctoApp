import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/errors.dart';
import '../core/supabase.dart';
import '../shared/models/models.dart';

/// Estado do usuário logado: perfil, empresas que ele enxerga e a empresa
/// selecionada no momento. Fica no topo do app via [SessionScope].
class AppSession extends ChangeNotifier {
  AppSession() {
    if (!AppConfig.isConfigured) {
      _ready = true;
      return;
    }
    _sub = sb.auth.onAuthStateChange.listen(_onAuthEvent);
    _restore();
  }

  StreamSubscription<AuthState>? _sub;
  bool _ready = false;
  bool _signingIn = false;
  bool recoveringPassword = false;

  Profile? profile;
  List<Company> companies = [];
  Company? _current;

  /// Fichas do cliente logado (uma por empresa em que ele é paciente).
  List<Patient> myPatients = [];

  bool get ready => _ready;
  bool get signedIn => profile != null;
  UserRole get role => profile?.role ?? UserRole.client;
  bool get isOwner => role == UserRole.owner;
  bool get isStaff => role == UserRole.staff;
  bool get isClient => role == UserRole.client;
  bool get isManager => isOwner || isStaff;

  /// Empresa em uso. Funcionário sempre a dele; chefe e cliente podem trocar.
  Company? get current => _current ?? (companies.isNotEmpty ? companies.first : null);

  void selectCompany(Company c) {
    _current = c;
    notifyListeners();
  }

  Patient? get myPatientInCurrent {
    final c = current;
    if (c == null) return null;
    for (final p in myPatients) {
      if (p.companyId == c.id) return p;
    }
    return null;
  }

  Future<void> _restore() async {
    try {
      if (sb.auth.currentSession != null) await _load();
    } catch (_) {
      await _clear();
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> _onAuthEvent(AuthState state) async {
    switch (state.event) {
      case AuthChangeEvent.passwordRecovery:
        recoveringPassword = true;
        notifyListeners();
      case AuthChangeEvent.signedOut:
        await _clear();
      case AuthChangeEvent.signedIn:
        // Entrada pelo link do e-mail (o login normal é tratado em signIn).
        if (!_signingIn && profile == null && !recoveringPassword) {
          try {
            await _load();
          } catch (_) {}
          notifyListeners();
        }
      default:
        break;
    }
  }

  /// [ownerArea]: true na tela "Gestor". O chefe tem um acesso separado:
  /// conta de chefe só entra pelo acesso do gestor e vice-versa.
  Future<void> signIn(String email, String password, {required bool ownerArea}) async {
    _signingIn = true;
    try {
      await sb.auth.signInWithPassword(email: email.trim(), password: password);
      final p = await _fetchProfile();
      if (p == null || !p.active) {
        await sb.auth.signOut();
        throw AppException('Este acesso está desativado. Fale com o responsável pela empresa.');
      }
      if (ownerArea && p.role != UserRole.owner) {
        await sb.auth.signOut();
        throw AppException('Esta conta não é de gestor. Use a aba "Clínica".');
      }
      if (!ownerArea && p.role == UserRole.owner) {
        await sb.auth.signOut();
        throw AppException('Esta é uma conta de gestor. Use a aba "Gestor".');
      }
      await _load(prefetched: p);
      notifyListeners();
    } finally {
      _signingIn = false;
    }
  }

  Future<void> signOut() async {
    await sb.auth.signOut();
    await _clear();
  }

  Future<void> finishPasswordRecovery() async {
    recoveringPassword = false;
    try {
      await _load();
    } catch (_) {
      await signOut();
    }
    notifyListeners();
  }

  Future<Profile?> _fetchProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final row = await sb.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  Future<void> _load({Profile? prefetched}) async {
    final p = prefetched ?? await _fetchProfile();
    if (p == null || !p.active) {
      await sb.auth.signOut();
      await _clear();
      return;
    }
    profile = p;
    await refreshCompanies();
  }

  Future<void> refreshProfile() async {
    final p = await _fetchProfile();
    if (p != null) {
      profile = p;
      notifyListeners();
    }
  }

  Future<void> refreshCompanies() async {
    final p = profile;
    if (p == null) return;
    final rows = await sb.from('companies').select().order('name', ascending: true);
    companies = rows.map(Company.fromMap).toList();
    if (p.role == UserRole.staff) {
      companies = companies.where((c) => c.id == p.companyId).toList();
    }
    if (p.role == UserRole.client) {
      final pts = await sb.from('patients').select().eq('user_id', p.id);
      myPatients = pts.map(Patient.fromMap).toList();
    }
    final keep = _current == null ? null : companies.where((c) => c.id == _current!.id);
    _current = (keep != null && keep.isNotEmpty) ? keep.first : null;
    notifyListeners();
  }

  Future<void> _clear() async {
    profile = null;
    companies = [];
    myPatients = [];
    _current = null;
    recoveringPassword = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

class SessionScope extends InheritedNotifier<AppSession> {
  const SessionScope({super.key, required AppSession session, required super.child})
      : super(notifier: session);

  static AppSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// Sem registrar dependência (para usar em callbacks).
  static AppSession read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
