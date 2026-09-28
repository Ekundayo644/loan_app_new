import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<double?> getInterestRate() async {
    final data = await _client
        .from('settings')
        .select('value')
        .eq('key', 'interest_rate')
        .maybeSingle();

    if (data == null) return null;
    return double.tryParse(data['value'].toString());
  }

  Future<void> updateInterestRate(double newRate) async {
    await _client.from('settings').upsert({
      'key': 'interest_rate',
      'value': newRate.toString(),
    });
  }
}