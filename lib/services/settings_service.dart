import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _tableName = 'settings';
  final String _configName = 'loan_config';

  /// Fetches the current interest rate from Supabase.
  /// Returns a default of 10% if not set.
  Future<double> getInterestRate() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('value')
          .eq('name', _configName)
          .single();

      final settings = response['value'] as Map<String, dynamic>;
      if (settings.containsKey('interest_rate')) {
        return (settings['interest_rate'] as num).toDouble();
      }
      
      return 0.10; // Default 10%
    } catch (e) {
      // This can fail if the row doesn't exist yet.
      print('Could not fetch interest rate, using default 10%. Error: $e');
      return 0.10;
    }
  }

  /// Updates the interest rate in the 'settings' table in Supabase.
  Future<void> setInterestRate(double newRate) async {
    try {
      await _supabase.from(_tableName).upsert({
        'name': _configName,
        'value': {'interest_rate': newRate},
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'name');
    } catch (e) {
      print('Error saving interest rate: $e');
      rethrow;
    }
  }
}
