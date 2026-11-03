import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/leave.dart';
import '../../domain/repositories/leave_repository.dart';
import '../datasources/leave_datasource.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  LeaveRepositoryImpl(this.source);
  final LeaveDataSource source;
  @override
  Future<Result<LeaveData>> load(int year) => guard(() => source.load(year));
  @override
  Future<Result<void>> apply(
    String type,
    DateTime start,
    DateTime end,
    bool half,
    String? period,
    String reason,
  ) => guard(() => source.apply(type, start, end, half, period, reason));
  @override
  Future<Result<void>> cancel(String id) => guard(() => source.cancel(id));
  @override
  Future<Result<void>> review(String id, bool approve, String comment) =>
      guard(() => source.review(id, approve, comment));
}
