import '../../../../core/error/result.dart';
import '../entities/leave.dart';
import '../repositories/leave_repository.dart';

class LeaveActions {
  LeaveActions(this.repository);
  final LeaveRepository repository;
  Future<Result<LeaveData>> load(int year) => repository.load(year);
  Future<Result<void>> apply(
    String type,
    DateTime start,
    DateTime end,
    bool half,
    String? period,
    String reason,
  ) => repository.apply(type, start, end, half, period, reason);
  Future<Result<void>> cancel(String id) => repository.cancel(id);
  Future<Result<void>> review(String id, bool approve, String comment) =>
      repository.review(id, approve, comment);
}
