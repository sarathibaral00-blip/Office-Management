import '../../domain/entities/attendance_reports.dart';

class AttendanceReportModel extends AttendanceReportRow {
  AttendanceReportModel.fromJson(Map<String, dynamic> j)
    : super(
        j['employee_id'] as String,
        j['full_name'] as String,
        j['employee_code'] as String,
        DateTime.parse(j['work_date'] as String),
        j['status'] as String,
        j['source'] as String,
        j['department_name'] as String? ?? 'Unassigned',
        j['branch_name'] as String? ?? 'Unassigned',
        j['check_in'] == null ? null : DateTime.parse(j['check_in'] as String),
        j['check_out'] == null
            ? null
            : DateTime.parse(j['check_out'] as String),
        (j['hours'] as num).toDouble(),
      );
}
