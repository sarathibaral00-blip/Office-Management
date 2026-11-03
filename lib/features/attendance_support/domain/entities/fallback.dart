import 'package:equatable/equatable.dart';

class FallbackEmployee extends Equatable {
  const FallbackEmployee(this.id, this.name, this.code, this.branchId);
  final String id, name, code;
  final String? branchId;
  @override
  List<Object?> get props => [id, name, code, branchId];
}

class OfficeBranch extends Equatable {
  const OfficeBranch(this.id, this.name);
  final String id, name;
  @override
  List<Object?> get props => [id, name];
}

class AttendanceDevice extends Equatable {
  const AttendanceDevice({
    required this.id,
    required this.label,
    required this.kind,
    required this.branchId,
    this.employeeId,
    this.expiresAt,
    this.revokedAt,
  });
  final String id, label, kind, branchId;
  final String? employeeId;
  final DateTime? expiresAt, revokedAt;
  bool active(DateTime now) =>
      revokedAt == null && (expiresAt == null || expiresAt!.isAfter(now));
  String status(DateTime now) => revokedAt != null
      ? 'Revoked'
      : expiresAt != null && !expiresAt!.isAfter(now)
      ? 'Expired'
      : 'Approved';
  @override
  List<Object?> get props => [
    id,
    label,
    kind,
    branchId,
    employeeId,
    expiresAt,
    revokedAt,
  ];
}

class ManualAlert extends Equatable {
  const ManualAlert(this.id, this.message, this.acknowledged);
  final String id, message;
  final bool acknowledged;
  @override
  List<Object?> get props => [id, message, acknowledged];
}

class SupportSnapshot extends Equatable {
  const SupportSnapshot(
    this.employees,
    this.branches,
    this.devices,
    this.alerts,
    this.limit,
  );
  final List<FallbackEmployee> employees;
  final List<OfficeBranch> branches;
  final List<AttendanceDevice> devices;
  final List<ManualAlert> alerts;
  final int limit;
  @override
  List<Object?> get props => [employees, branches, devices, alerts, limit];
}

class SupportRecord extends Equatable {
  const SupportRecord({
    required this.id,
    required this.employeeId,
    required this.day,
    required this.checkIn,
    this.checkOut,
    required this.source,
    required this.status,
    this.reason,
  });
  final String id, employeeId, source, status;
  final DateTime day, checkIn;
  final DateTime? checkOut;
  final String? reason;
  @override
  List<Object?> get props => [
    id,
    employeeId,
    day,
    checkIn,
    checkOut,
    source,
    status,
    reason,
  ];
}

class RecordPage extends Equatable {
  const RecordPage(this.records, this.hasMore);
  final List<SupportRecord> records;
  final bool hasMore;
  @override
  List<Object?> get props => [records, hasMore];
}

class ManualSubmission extends Equatable {
  const ManualSubmission({
    required this.employeeId,
    required this.checkIn,
    required this.reason,
    this.checkOut,
    this.attendanceId,
  });
  final String employeeId, reason;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? attendanceId;
  @override
  List<Object?> get props => [
    employeeId,
    checkIn,
    checkOut,
    reason,
    attendanceId,
  ];
}

class SupportOutcome extends Equatable {
  const SupportOutcome({
    this.exceeded = false,
    this.count = 0,
    this.limit = 3,
    this.paired = false,
  });
  final bool exceeded, paired;
  final int count, limit;
  @override
  List<Object?> get props => [exceeded, count, limit, paired];
}

class DevicePairing extends Equatable {
  const DevicePairing(this.id, this.label, this.kind, this.expiresAt);
  final String id, label, kind;
  final DateTime? expiresAt;
  @override
  List<Object?> get props => [id, label, kind, expiresAt];
}

class DeviceSubmission {
  const DeviceSubmission({
    required this.action,
    required this.code,
    required this.pin,
  });
  final String action, code, pin;
}
