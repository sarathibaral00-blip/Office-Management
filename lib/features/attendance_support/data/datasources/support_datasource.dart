import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/fallback.dart';
import '../models/support_models.dart';

class SupportDataSource {
  SupportDataSource(this.client);
  final SupabaseClient client;
  // Device bearer material lives only in process memory. Reloading requires HR
  // to rotate/re-pair; it is never put in routes, preferences or audit records.
  String? _token;
  DevicePairing? pairing;
  String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Future<Map<String, dynamic>> invoke(
    String action, [
    Map<String, Object?> data = const {},
  ]) async {
    final body = action == 'manual'
        ? {'action': action, ...data}
        : {'action': action, 'data': data};
    final r = await client.functions.invoke('attendance-admin', body: body);
    final value = Map<String, dynamic>.from(r.data as Map);
    if (value['device_token'] is String) {
      _token = value['device_token'] as String;
      pairing = DevicePairing(
        value['device_id'] as String,
        value['label'] as String,
        value['kind'] as String,
        value['expires_at'] == null
            ? null
            : DateTime.parse(value['expires_at'] as String),
      );
    }
    return value;
  }

  Future<SupportSnapshot> snapshot() async {
    await invoke('refresh_expiry');
    if (pairing?.expiresAt != null &&
        !pairing!.expiresAt!.isAfter(DateTime.now())) {
      clearPairing();
    }
    final employees = <FallbackEmployee>[];
    int offset = 0;
    while (true) {
      final rows = await client
          .from('profiles')
          .select('id,full_name,employee_code,branch_id')
          .order('id')
          .range(offset, offset + 199);
      employees.addAll(
        rows.map(
          (j) => FallbackEmployee(
            j['id'] as String,
            j['full_name'] as String,
            j['employee_code'] as String,
            j['branch_id'] as String?,
          ),
        ),
      );
      if (rows.length < 200) break;
      offset += 200;
    }
    final branches = <OfficeBranch>[];
    offset = 0;
    while (true) {
      final rows = await client
          .from('branches')
          .select('id,name')
          .order('id')
          .range(offset, offset + 199);
      branches.addAll(
        rows.map((j) => OfficeBranch(j['id'] as String, j['name'] as String)),
      );
      if (rows.length < 200) break;
      offset += 200;
    }
    final devices = <AttendanceDevice>[];
    offset = 0;
    while (true) {
      final rows = await client
          .from('attendance_devices')
          .select()
          .order('id')
          .range(offset, offset + 199);
      devices.addAll(rows.map(DeviceModel.fromJson));
      if (rows.length < 200) break;
      offset += 200;
    }
    final alerts = <ManualAlert>[];
    offset = 0;
    while (true) {
      final rows = await client
          .from('hr_attendance_alerts')
          .select('id,message,acknowledged_at')
          .isFilter('acknowledged_at', null)
          .order('id')
          .range(offset, offset + 199);
      alerts.addAll(
        rows.map(
          (j) => ManualAlert(
            j['id'] as String,
            j['message'] as String,
            j['acknowledged_at'] != null,
          ),
        ),
      );
      if (rows.length < 200) break;
      offset += 200;
    }
    final settings = await client
        .from('attendance_settings')
        .select('monthly_manual_limit')
        .eq('singleton', true)
        .single();
    return SupportSnapshot(
      employees,
      branches,
      devices,
      alerts,
      settings['monthly_manual_limit'] as int,
    );
  }

  Future<SupportRecord?> record(String employee, DateTime day) async {
    final j = await client
        .from('attendance')
        .select()
        .eq('employee_id', employee)
        .eq('work_date', dayKey(day))
        .maybeSingle();
    return j == null ? null : SupportRecordModel.fromJson(j);
  }

  Future<RecordPage> report(DateTime month, int offset) async {
    final rows = await client
        .from('attendance')
        .select()
        .neq('source', 'app')
        .gte('work_date', dayKey(DateTime(month.year, month.month)))
        .lt('work_date', dayKey(DateTime(month.year, month.month + 1)))
        .order('work_date', ascending: false)
        .order('id')
        .range(offset, offset + 50);
    return RecordPage(
      rows.take(50).map(SupportRecordModel.fromJson).toList(),
      rows.length > 50,
    );
  }

  Future<SupportOutcome> manual(ManualSubmission s) async {
    final r = await invoke('manual', {
      'employee_id': s.employeeId,
      'check_in': s.checkIn.toUtc().toIso8601String(),
      'check_out': s.checkOut?.toUtc().toIso8601String(),
      'reason': s.reason,
      'attendance_id': s.attendanceId,
    });
    return SupportOutcome(
      exceeded: r['limit_exceeded'] == true,
      count: r['manual_count'] as int,
      limit: r['limit'] as int,
    );
  }

  Future<SupportOutcome> manage(
    String action,
    Map<String, Object?> data,
  ) async {
    final r = await invoke(action, data);
    if (action == 'revoke_device' && data['id'] == pairing?.id) {
      clearPairing();
    }
    return SupportOutcome(paired: r['device_token'] != null);
  }

  void clearPairing() {
    _token = null;
    pairing = null;
  }

  Future<void> devicePunch(DeviceSubmission s) async {
    final device = pairing;
    final token = _token;
    if (device == null || token == null) {
      throw const FormatException('This device needs HR approval');
    }
    await client.functions.invoke(
      'check-in',
      body: {
        'mode': device.kind,
        'device_id': device.id,
        'device_token': token,
        'employee_code': s.code,
        'pin': s.pin,
        'action': s.action,
      },
    );
  }
}
