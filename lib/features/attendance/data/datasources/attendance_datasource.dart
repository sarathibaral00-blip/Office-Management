import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/attendance.dart';
import '../models/attendance_model.dart';

class AttendanceDataSource {
  AttendanceDataSource(this.client);
  final SupabaseClient client;
  Future<WorkMonth> month(DateTime? m) async {
    final id = client.auth.currentUser!.id;
    final p = await client
        .from('profiles')
        .select('branch_id,shift_id,joined_at')
        .eq('id', id)
        .single();
    // All work dates are branch dates, not device dates. The clock RPC uses PostgreSQL timezone data.
    final day = await client.rpc('employee_today');
    m ??= DateTime.parse(day as String);
    final open = await client
        .from('attendance')
        .select()
        .eq('employee_id', id)
        .isFilter('check_out', null)
        .maybeSingle();
    final rows = await client
        .from('attendance')
        .select()
        .eq('employee_id', id)
        .gte('work_date', WorkMonth.key(DateTime(m.year, m.month)))
        .lt('work_date', WorkMonth.key(DateTime(m.year, m.month + 1)))
        .order('work_date');
    final holidays = await client
        .from('holidays')
        .select('holiday_date,branch_id,name')
        .eq('is_active', true)
        .gte('holiday_date', WorkMonth.key(DateTime(m.year, m.month)))
        .lt('holiday_date', WorkMonth.key(DateTime(m.year, m.month + 1)));
    final shifts = p['shift_id'] == null
        ? await client
              .from('shifts')
              .select('work_days')
              .eq('is_default', true)
              .maybeSingle()
        : await client
              .from('shifts')
              .select('work_days')
              .eq('id', p['shift_id'])
              .maybeSingle();
    final approved = await client
        .from('leave_requests')
        .select('starts_on,ends_on,is_half_day')
        .eq('employee_id', id)
        .eq('status', 'approved')
        .lte('starts_on', WorkMonth.key(DateTime(m.year, m.month + 1, 0)))
        .gte('ends_on', WorkMonth.key(DateTime(m.year, m.month)));
    final leaveUnits = <String, double>{};
    for (final r in approved) {
      final start = DateTime.parse(r['starts_on'] as String);
      final end = DateTime.parse(r['ends_on'] as String);
      for (
        var d = DateTime(m.year, m.month);
        d.month == m.month;
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        if (!d.isBefore(start) && !d.isAfter(end)) {
          final key = WorkMonth.key(d);
          leaveUnits[key] =
              ((leaveUnits[key] ?? 0) + (r['is_half_day'] == true ? 0.5 : 1.0))
                  .clamp(0, 1)
                  .toDouble();
        }
      }
    }
    return WorkMonth(
      rows.map(AttendanceModel.fromJson).toList(),
      holidays
          .where(
            (h) => h['branch_id'] == null || h['branch_id'] == p['branch_id'],
          )
          .map((h) => h['holiday_date'] as String)
          .toSet(),
      List<int>.from(shifts?['work_days'] ?? [0, 1, 2, 3, 4]),
      DateTime.parse(day as String),
      open: open == null ? null : AttendanceModel.fromJson(open),
      leaveUnits: leaveUnits,
      holidayNames: {
        for (final h in holidays.where(
          (h) => h['branch_id'] == null || h['branch_id'] == p['branch_id'],
        ))
          h['holiday_date'] as String: h['name'] as String,
      },
      joinedAt: DateTime.parse(p['joined_at'] as String),
    );
  }

  Future<dynamic> invoke(String action) async {
    final r = await client.functions.invoke(
      'check-in',
      body: {'action': action},
    );
    return r.data;
  }

  Future<void> punch(String a) async {
    await invoke(a);
  }

  Future<bool> network() async {
    final d = await invoke('status');
    return d['allowed'] == true;
  }
}
