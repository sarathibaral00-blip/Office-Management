import '../../../../core/error/result.dart';
import '../entities/attendance_reports.dart';
import '../repositories/attendance_reports_repository.dart';

class AttendanceReportsActions {
  AttendanceReportsActions(this.repository);
  final AttendanceReportsRepository repository;
  Future<Result<AttendanceReportData>> load(
    DateTime start,
    DateTime end,
    String? department,
    String? branch,
    int offset,
  ) => repository.load(start, end, department, branch, offset);
}
