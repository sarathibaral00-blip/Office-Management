import '../../../../core/error/result.dart';
import '../entities/attendance.dart';

abstract class AttendanceRepository {
  Future<Result<WorkMonth>> month(DateTime? month);
  Future<Result<void>> punch(String action);
  Future<Result<bool>> network();
}
