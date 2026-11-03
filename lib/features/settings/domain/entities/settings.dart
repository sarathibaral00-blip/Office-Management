import 'package:equatable/equatable.dart';

class CompanyPolicy extends Equatable {
  const CompanyPolicy(this.values);
  final Map<String, Object?> values;
  @override
  List<Object?> get props => [values];
}

class ShiftSchedule extends Equatable {
  const ShiftSchedule(
    this.id,
    this.name,
    this.start,
    this.end,
    this.grace,
    this.days,
    this.defaultShift,
  );
  final String id, name, start, end;
  final int grace;
  final List<int> days;
  final bool defaultShift;
  @override
  List<Object?> get props => [id, name, start, end, grace, days, defaultShift];
}

class RoleCapability extends Equatable {
  const RoleCapability(this.role, this.key, this.enabled);
  final String role, key;
  final bool enabled;
  @override
  List<Object?> get props => [role, key, enabled];
}

class SettingsData extends Equatable {
  const SettingsData(
    this.company,
    this.shifts,
    this.permissions,
    this.audit,
    this.auditMore,
  );
  final CompanyPolicy? company;
  final List<ShiftSchedule> shifts;
  final List<RoleCapability> permissions;
  final List<Map<String, Object?>> audit;
  final bool auditMore;
  @override
  List<Object?> get props => [company, shifts, permissions, audit, auditMore];
}
