import '../../domain/entities/fallback.dart';

class SupportRecordModel extends SupportRecord {
  SupportRecordModel.fromJson(Map<String, dynamic> j)
    : super(
        id: j['id'] as String,
        employeeId: j['employee_id'] as String,
        day: DateTime.parse(j['work_date'] as String),
        checkIn: DateTime.parse(j['check_in'] as String),
        checkOut: j['check_out'] == null
            ? null
            : DateTime.parse(j['check_out'] as String),
        source: j['source'] as String? ?? 'app',
        status: j['status'] as String,
        reason: j['manual_reason'] as String?,
      );
}

class DeviceModel extends AttendanceDevice {
  DeviceModel.fromJson(Map<String, dynamic> j)
    : super(
        id: j['id'] as String,
        label: j['label'] as String,
        kind: j['kind'] as String,
        branchId: j['branch_id'] as String,
        employeeId: j['employee_id'] as String?,
        expiresAt: j['expires_at'] == null
            ? null
            : DateTime.parse(j['expires_at'] as String),
        revokedAt: j['revoked_at'] == null
            ? null
            : DateTime.parse(j['revoked_at'] as String),
      );
}
