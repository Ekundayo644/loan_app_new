import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' show AppUser;
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _auth = AuthService();

    // Subscribe to Supabase auth state changes
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
      _session = state.session;
      _user = state.session?.user;
      if (_user != null) {
        await _refresh();
      } else {
        _appUser = null;
        notifyListeners();
      }
    });

    // Seed initial state from persisted session (cold start)
    _session = Supabase.instance.client.auth.currentSession;
    _user = _session?.user;
    if (_user != null) {
      _refresh();
    }
  }

  late final AuthService _auth;
  late final dynamic _authSub;

  Session? _session;
  User? _user;
  AppUser? _appUser;

  // ---------- Getters ----------
  bool get isLoggedIn => _user != null;
  bool get isAuthenticated => _user != null; // used by splash_screen
  User? get user => _user;
  Session? get session => _session;
  AppUser? get appUser => _appUser;
  AppUser? get profile => _appUser;

  /// Best-effort display name: DB full_name → metadata full_name → email prefix
  String get displayName {
    final p = _appUser;
    if (p != null && p.fullName.isNotEmpty) return p.fullName;
    final meta = _user?.userMetadata?['full_name']?.toString();
    if (meta != null && meta.isNotEmpty) return meta;
    return _user?.email?.split('@').first ?? 'User';
  }

  String get role => _appUser?.role ?? 'customer';
  String? get email => _user?.email;

  Future<void> _refresh() async {
    try {
      _appUser = await _auth.getCurrentUser();
      debugPrint('✅ AuthProvider: user=${_appUser?.fullName} role=${_appUser?.role}');
    } catch (e, st) {
      _appUser = null;
      debugPrint('❌ AuthProvider._refresh failed: $e');
      debugPrint('$st');
    }
    notifyListeners();
  }

  /// Reload profile from DB (public).
  Future<void> loadProfile() => _refresh();

  /// Called by splash_screen — checks session and loads profile if present.
  Future<void> checkAuthStatus() async {
    _session = Supabase.instance.client.auth.currentSession;
    _user = _session?.user;
    if (_user != null) {
      await _refresh();
    } else {
      _appUser = null;
      notifyListeners();
    }
  }

  // ---------- Login (matches screens) ----------
  /// Returns null on success, or an error message string.
  Future<String?> login(String email, String password) async {
    try {
      await _auth.login(email, password);
      await _refresh();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // ---------- Register (matches screens) ----------
  /// Returns null on success, or an error message string.
  Future<String?> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String role = 'customer',
  }) async {
    try {
      await _auth.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );
      // If email confirmation is enabled, no session exists yet — don't
      // try to fetch the profile or the user will appear signed out.
      if (Supabase.instance.client.auth.currentSession != null) {
        await _refresh();
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // ---------- Aliases for code that calls signIn/signUp ----------
  Future<String?> signIn({required String email, required String password}) =>
      login(email, password);

  Future<String?> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String role = 'customer',
  }) =>
      register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );

  // ---------- Logout ----------
  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (e) {
      debugPrint('❌ logout failed: $e');
    }
    _session = null;
    _user = null;
    _appUser = null;
    notifyListeners();
  }

  Future<void> signOut() => logout();

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}