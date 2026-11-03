import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_datasource.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(this.source);
  final AttendanceDataSource source;
  @override
  Future<Result<WorkMonth>> month(DateTime? m) => guard(() => source.month(m));
  @override
  Future<Result<void>> punch(String a) => guard(() => source.punch(a));
  @override
  Future<Result<bool>> network() => guard(source.network);
}
