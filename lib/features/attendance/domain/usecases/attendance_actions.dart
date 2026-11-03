import '../../../../core/error/result.dart';
import '../entities/attendance.dart';
import '../repositories/attendance_repository.dart';

class AttendanceActions {
  AttendanceActions(this.repository);
  final AttendanceRepository repository;
  Future<Result<WorkMonth>> month(DateTime? m) => repository.month(m);
  Future<Result<void>> punch(String a) => repository.punch(a);
  Future<Result<bool>> network() => repository.network();
}
