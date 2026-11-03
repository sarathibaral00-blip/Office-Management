import '../../../../core/error/result.dart';
import '../entities/leave.dart';

abstract class LeaveRepository {
  Future<Result<LeaveData>> load(int year);
  Future<Result<void>> apply(
    String type,
    DateTime start,
    DateTime end,
    bool half,
    String? period,
    String reason,
  );
  Future<Result<void>> cancel(String id);
  Future<Result<void>> review(String id, bool approve, String comment);
}
