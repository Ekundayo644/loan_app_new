import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Supabase client instance
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Keep for backward compatibility with existing code
  static const String baseUrl = 'https://adxjesmeaqmykbpjulhb.supabase.co/rest/v1/';; // Replace with your URL

  // ============= AUTHENTICATION METHODS =============

  // Register user with Supabase Auth
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: userData,
      );

      if (response.user == null) {
        throw Exception('Registration failed: No user returned');
      }

      // Also insert into users table (if not using auth hooks)
      await _supabase.from('users').insert({
        'id': response.user!.id,
        ...userData,
        'created_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'user': response.user,
        'token': response.session?.accessToken,
        'user_id': response.user!.id,
      };
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // Login with Supabase Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed: No user returned');
      }

      return {
        'success': true,
        'user': response.user,
        'token': response.session?.accessToken,
        'user_id': response.user!.id,
      };
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      await clearAuthToken();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  // Get current user
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return null;

      return {
        'id': session.user.id,
        'email': session.user.email,
        'user_metadata': session.user.userMetadata,
        'token': session.accessToken,
      };
    } catch (e) {
      return null;
    }
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return _supabase.auth.currentSession != null;
  }

  // Get current session
  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  // ============= REST API METHODS (Supabase Tables) =============

  // POST: Insert data into a table
  Future<Map<String, dynamic>> post(String table, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from(table)
          .insert(data)
          .select()
          .single();

      return {'success': true, 'data': response};
    } catch (e) {
      throw Exception('POST request failed: $e');
    }
  }

  // POST with custom endpoint (legacy compatibility)
  Future<Map<String, dynamic>> postEndpoint(String endpoint, Map<String, dynamic> data) async {
    try {
      // Parse endpoint to extract table name
      final table = endpoint.split('?')[0].replaceAll('.php', '');
      final response = await _supabase
          .from(table)
          .insert(data)
          .select();

      return {'success': true, 'data': response};
    } catch (e) {
      throw Exception('POST request failed: $e');
    }
  }

  // GET: Fetch data from a table
  Future<Map<String, dynamic>> get(
    String table, {
    Map<String, String>? queryParams,
    String? filterColumn,
    dynamic filterValue,
    bool single = false,
  }) async {
    try {
      var query = _supabase.from(table).select();

      // Apply filters
      if (filterColumn != null && filterValue != null) {
        query = query.eq(filterColumn, filterValue);
      }

      // Apply query parameters (like status, limit, etc.)
      if (queryParams != null) {
        for (var entry in queryParams.entries) {
          if (entry.key == 'limit') {
            query = query.limit(int.parse(entry.value));
          } else if (entry.key == 'order') {
            query = query.order(entry.value, ascending: false);
          } else {
            query = query.eq(entry.key, entry.value);
          }
        }
      }

      final response = single 
          ? await query.single()
          : await query;

      return {'success': true, 'data': response};
    } catch (e) {
      throw Exception('GET request failed: $e');
    }
  }

  // GET with custom endpoint (legacy compatibility)
  Future<Map<String, dynamic>> getEndpoint(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      // Parse endpoint to extract table name and action
      final parts = endpoint.split('?');
      final table = parts[0].replaceAll('.php', '');
      
      var query = _supabase.from(table).select();

      // Parse query parameters
      if (queryParams != null) {
        for (var entry in queryParams.entries) {
          if (entry.key == 'action') continue; // Skip action param
          if (entry.key == 'loan_id' || entry.key == 'id') {
            query = query.eq('id', int.parse(entry.value));
          } else if (entry.key == 'limit') {
            query = query.limit(int.parse(entry.value));
          } else {
            query = query.eq(entry.key, entry.value);
          }
        }
      }

      final response = await query;

      return {'success': true, 'data': response};
    } catch (e) {
      throw Exception('GET request failed: $e');
    }
  }

  // PUT: Update data in a table
  Future<Map<String, dynamic>> put(
    String table, {
    required Map<String, dynamic> data,
    required String filterColumn,
    required dynamic filterValue,
  }) async {
    try {
      final response = await _supabase
          .from(table)
          .update(data)
          .eq(filterColumn, filterValue)
          .select()
          .single();

      return {'success': true, 'data': response};
    } catch (e) {
      throw Exception('PUT request failed: $e');
    }
  }

  // PUT with custom endpoint (legacy compatibility)
  Future<Map<String, dynamic>> putEndpoint(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      // Parse endpoint to extract table
      final table = endpoint.split('?')[0].replaceAll('.php', '');
      
      // Try to find ID in data
      final id = data['id'] ?? data['loan_id'];
      if (id == null) {
        throw Exception('ID required for update');
      }

      final response = await _supabase
          .from(table)
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return {'success': true, 'data': response};
    } catch (e) {
      throw Exception('PUT request failed: $e');
    }
  }

  // DELETE: Delete data from a table
  Future<Map<String, dynamic>> delete(
    String table, {
    required String filterColumn,
    required dynamic filterValue,
  }) async {
    try {
      await _supabase
          .from(table)
          .delete()
          .eq(filterColumn, filterValue);

      return {'success': true};
    } catch (e) {
      throw Exception('DELETE request failed: $e');
    }
  }

  // ============= TOKEN MANAGEMENT (SharedPreferences) =============

  // Set auth token
  Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Get auth token
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Clear auth token
  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ============= HEADERS (Backward Compatibility) =============

  // Get headers for HTTP requests (if still using http package)
  Future<Map<String, String>> _getHeaders() async {
    final token = await getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============= REAL-TIME SUBSCRIPTIONS =============

  // Subscribe to table changes
  void subscribeToTable(
    String table, {
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Map<String, dynamic>) onDelete,
    String? filterColumn,
    dynamic filterValue,
  }) {
    var channel = _supabase
        .channel('public:$table')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: table,
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          callback: (payload) => onDelete(payload.oldRecord),
        )
        .subscribe();

    // You can store this channel to unsubscribe later
    // _subscriptions.add(channel);
  }

  // Unsubscribe from a channel
  void unsubscribe(String channelName) {
    _supabase.removeChannel(channelName);
  }

  // ============= STORAGE (File Uploads) =============

  // Upload file to Supabase Storage
  Future<String> uploadFile(
    String bucket,
    String path,
    dynamic file, // File, Uint8List, or String
  ) async {
    try {
      await _supabase.storage.from(bucket).upload(path, file);
      final url = _supabase.storage.from(bucket).getPublicUrl(path);
      return url;
    } catch (e) {
      throw Exception('File upload failed: $e');
    }
  }

  // Delete file from Supabase Storage
  Future<void> deleteFile(String bucket, String path) async {
    try {
      await _supabase.storage.from(bucket).remove([path]);
    } catch (e) {
      throw Exception('File deletion failed: $e');
    }
  }

  // ============= HELPER METHODS =============

  // Check if table exists
  Future<bool> tableExists(String table) async {
    try {
      await _supabase.from(table).select().limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get count of records in a table
  Future<int> getCount(String table, {String? filterColumn, dynamic filterValue}) async {
    try {
      var query = _supabase.from(table).select('*', count: CountOption.exact);
      if (filterColumn != null && filterValue != null) {
        query = query.eq(filterColumn, filterValue);
      }
      final response = await query;
      return response.length;
    } catch (e) {
      throw Exception('Count query failed: $e');
    }
  }

  // ============= RPC (Call PostgreSQL Functions) =============

  // Call a PostgreSQL function (RPC)
  Future<dynamic> rpc(String functionName, Map<String, dynamic> params) async {
    try {
      final response = await _supabase.rpc(functionName, params: params);
      return response;
    } catch (e) {
      throw Exception('RPC call failed: $e');
    }
  }
}

// ============= SINGLETON INSTANCE =============

class ApiServiceSingleton {
  static final ApiService _instance = ApiService();
  
  static ApiService get instance => _instance;
}