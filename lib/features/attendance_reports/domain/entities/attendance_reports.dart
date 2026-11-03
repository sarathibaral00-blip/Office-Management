import 'package:equatable/equatable.dart';
import '../../../../core/domain/page_result.dart';

class AttendanceReportRow extends Equatable {
  const AttendanceReportRow(
    this.employee,
    this.name,
    this.code,
    this.day,
    this.status,
    this.source,
    this.department,
    this.branch,
    this.checkIn,
    this.checkOut,
    this.hours,
  );
  final String employee, name, code, status, source, department, branch;
  final DateTime day;
  final DateTime? checkIn, checkOut;
  final double hours;
  @override
  List<Object?> get props => [
    employee,
    name,
    code,
    day,
    status,
    source,
    department,
    branch,
    checkIn,
    checkOut,
    hours,
  ];
}

class AttendanceReportData extends Equatable {
  const AttendanceReportData(
    this.page,
    this.departments,
    this.branches,
    this.total,
    this.present,
    this.late,
    this.absent,
    this.hours,
  );
  final PageResult<AttendanceReportRow> page;
  final List<Choice> departments, branches;
  final int total, present, late;
  final double absent;
  final double hours;
  @override
  List<Object?> get props => [
    page,
    departments,
    branches,
    total,
    present,
    late,
    absent,
    hours,
  ];
}
