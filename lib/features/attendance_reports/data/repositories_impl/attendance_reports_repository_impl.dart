import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/attendance_reports.dart';
import '../../domain/repositories/attendance_reports_repository.dart';
import '../datasources/attendance_reports_datasource.dart';

class AttendanceReportsRepositoryImpl implements AttendanceReportsRepository {
  AttendanceReportsRepositoryImpl(this.source);
  final AttendanceReportsDataSource source;
  @override
  Future<Result<AttendanceReportData>> load(
    DateTime start,
    DateTime end,
    String? department,
    String? branch,
    int offset,
  ) => guard(() => source.load(start, end, department, branch, offset));
}
