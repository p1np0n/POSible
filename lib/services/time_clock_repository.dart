import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/current_store.dart';
import '../models/time_clock_entry.dart';

class TimeClockRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<TimeClockEntry?> getMyOpenEntry() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await _client
        .from('time_clock_entries')
        .select()
        .eq('user_id', userId)
        .isFilter('clock_out', null)
        .order('clock_in', ascending: false)
        .limit(1)
        .maybeSingle();
    return data == null ? null : TimeClockEntry.fromMap(data);
  }

  Future<List<TimeClockEntry>> getMyHistory({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _client
        .from('time_clock_entries')
        .select()
        .eq('user_id', userId)
        .order('clock_in', ascending: false)
        .limit(limit);
    return (data as List).map((e) => TimeClockEntry.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> clockIn() async {
    final user = _client.auth.currentUser!;
    await _client.from('time_clock_entries').insert({
      'user_id': user.id,
      'user_email': user.email,
      'store_id': CurrentStore.id,
    });
  }

  Future<void> clockOut(String id) async {
    await _client
        .from('time_clock_entries')
        .update({'clock_out': DateTime.now().toIso8601String()}).eq('id', id);
  }
}
