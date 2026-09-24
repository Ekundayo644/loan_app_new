import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loan_app_new/models/user.dart' show AppUser;

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============= REGISTER =============
  Future<AppUser> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String role = 'customer',
  }) async {
    try {
      print('=== SIGNUP ATTEMPT ===');
      print('email: $email');

      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': role,
        },
      );

      print('=== SIGNUP RESPONSE ===');
      print('user id: ${authResponse.user?.id}');
      print('session: ${authResponse.session}');

      if (authResponse.user == null) {
        throw Exception('Registration failed: No user returned');
      }

      return AppUser.fromJson({
        'id': authResponse.user!.id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'token': authResponse.session?.accessToken ?? '',
      });
    } catch (e, stack) {
      print('=== SIGNUP ERROR ===');
      print('error: $e');
      print('stack: $stack');
      throw Exception('Registration failed: $e');
    }
  }

  // ============= LOGIN =============
  Future<AppUser> login(String email, String password) async {
    try {
      print('=== LOGIN ATTEMPT ===');
      print('email: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed: No user returned');
      }

      print('auth user id: ${response.user!.id}');
      print('auth metadata: ${response.user!.userMetadata}');

      // Try to read the profile row (source of truth for role)
      Map<String, dynamic>? userData;
      String? dbError;
      try {
        userData = await _supabase
            .from('users')
            .select()
            .eq('id', response.user!.id)
            .single();
        print('=== DB profile loaded ===');
        print('DB role: ${userData['role']}');
        print('DB full_name: ${userData['full_name']}');
      } catch (e) {
        dbError = e.toString();
        print('=== DB read FAILED ===');
        print(dbError);
        userData = null;
      }

      // Priority: DB role > metadata role > 'customer'
      final metaRole = response.user!.userMetadata?['role'] as String?;
      final role = (userData?['role'] as String?)
          ?? metaRole
          ?? 'customer';

      print('=== FINAL ROLE: $role ===');

      return AppUser.fromJson({
        'id': response.user!.id,
        'full_name': userData?['full_name']
            ?? response.user!.userMetadata?['full_name']
            ?? '',
        'email': userData?['email'] ?? response.user!.email ?? email,
        'phone': userData?['phone']
            ?? response.user!.userMetadata?['phone']
            ?? '',
        'role': role,
        'profile_image': userData?['profile_image'],
        'created_at': userData?['created_at'],
        'token': response.session?.accessToken ?? '',
      });
    } catch (e, stack) {
      print('=== LOGIN ERROR ===');
      print('error: $e');
      print('stack: $stack');
      throw Exception('Login failed: $e');
    }
  }

  // ============= LOGOUT =============
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  // ============= GET CURRENT USER =============
  Future<AppUser?> getCurrentUser() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        print('=== getCurrentUser: no session ===');
        return null;
      }

      print('=== getCurrentUser: session user id: ${session.user.id}');

      Map<String, dynamic>? userData;
      try {
        userData = await _supabase
            .from('users')
            .select()
            .eq('id', session.user.id)
            .single();
        print('DB role: ${userData['role']}');
      } catch (e) {
        print('=== getCurrentUser DB read FAILED ===');
        print(e.toString());
        userData = null;
      }

      final metaRole = session.user.userMetadata?['role'] as String?;
      final role = (userData?['role'] as String?)
          ?? metaRole
          ?? 'customer';

      print('=== getCurrentUser FINAL ROLE: $role ===');

      return AppUser.fromJson({
        'id': session.user.id,
        'full_name': userData?['full_name']
            ?? session.user.userMetadata?['full_name']
            ?? '',
        'email': userData?['email'] ?? session.user.email ?? '',
        'phone': userData?['phone']
            ?? session.user.userMetadata?['phone']
            ?? '',
        'role': role,
        'profile_image': userData?['profile_image'],
        'created_at': userData?['created_at'],
        'token': session.accessToken,
      });
    } catch (e) {
      print('=== getCurrentUser outer error: $e ===');
      return null;
    }
  }

  // ============= GET TOKEN =============
  Future<String?> getToken() async {
    try {
      return _supabase.auth.currentSession?.accessToken;
    } catch (e) {
      return null;
    }
  }

  // ============= CHECK IF LOGGED IN =============
  bool isLoggedIn() {
    return _supabase.auth.currentSession != null;
  }

  // ============= RESET PASSWORD =============
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }
}