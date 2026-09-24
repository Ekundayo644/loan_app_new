import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loan_app_new/models/user.dart' show AppUser;
import 'package:loan_app_new/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;

  // ============= REGISTER =============
  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String role = 'customer',
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );

      _user = user;
      _isAuthenticated = Supabase.instance.client.auth.currentSession != null;

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ============= LOGIN =============
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.login(email, password);

      _user = user;
      _isAuthenticated = Supabase.instance.client.auth.currentSession != null;

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ============= LOGOUT =============
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.logout();
      _user = null;
      _isAuthenticated = false;
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============= CHECK AUTH STATUS =============
  Future<void> checkAuthStatus() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        _user = null;
        _isAuthenticated = false;
        notifyListeners();
        return;
      }

      final user = await _authService.getCurrentUser();
      if (user != null) {
        _user = user;
        _isAuthenticated = true;
      } else {
        _user = null;
        _isAuthenticated = false;
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _user = null;
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  // ============= GET TOKEN =============
  Future<String?> getToken() async {
    return await _authService.getToken();
  }

  // ============= PRIVATE METHODS =============
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}