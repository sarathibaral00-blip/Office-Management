import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/leave.dart';
import '../models/leave_model.dart';

class LeaveDataSource {
  LeaveDataSource(this.client);
  final SupabaseClient client;

  String key(DateTime d) => d.toIso8601String().split('T').first;
  Future<LeaveData> load(int year) async {
    await client.rpc('ensure_leave_balances', params: {'p_year': year});
    final types = await client.from('leave_types').select();
    final rows = await client
        .from('leave_balances')
        .select()
        .eq('employee_id', client.auth.currentUser!.id)
        .eq('year', year);
    final balances = types.map((t) {
      final b = rows.where((r) => r['leave_type_id'] == t['id']).firstOrNull;
      return LeaveBalance(
        t['id'] as String,
        t['name'] as String,
        (b?['allocated'] as num? ?? 0).toDouble(),
        (b?['used'] as num? ?? 0).toDouble(),
        t['is_paid'] as bool,
      );
    }).toList();
    final entries = <LeaveEntry>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('leave_requests')
          .select('*,profiles!leave_requests_employee_id_fkey(full_name)')
          .lte('starts_on', '$year-12-31')
          .gte('ends_on', '$year-01-01')
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      entries.addAll(
        rows.map((j) => LeaveModel.fromJson(j, client.auth.currentUser!.id)),
      );
      if (rows.length < 200) break;
    }
    return LeaveData(balances, entries);
  }

  Future<void> apply(
    String type,
    DateTime start,
    DateTime end,
    bool half,
    String? period,
    String reason,
  ) async {
    await client.rpc(
      'apply_leave',
      params: {
        'p_type': type,
        'p_start': key(start),
        'p_end': key(end),
        'p_half': half,
        'p_period': period,
        'p_reason': reason,
      },
    );
  }

  Future<void> cancel(String id) async {
    await client.rpc('cancel_leave', params: {'p_id': id});
  }

  Future<void> review(String id, bool approve, String comment) async {
    await client.rpc(
      'review_leave',
      params: {'p_id': id, 'p_approve': approve, 'p_comment': comment},
    );
  }
}
