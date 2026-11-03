import '../../../../core/error/result.dart';
import '../entities/attendance_reports.dart';

abstract class AttendanceReportsRepository {
  Future<Result<AttendanceReportData>> load(
    DateTime start,
    DateTime end,
    String? department,
    String? branch,
    int offset,
  );
}
