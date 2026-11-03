import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/financing.dart';
import '../../domain/repositories/financing_repository.dart';
import '../datasources/financing_datasource.dart';

class FinancingRepositoryImpl implements FinancingRepository {
  FinancingRepositoryImpl(this.source);
  final FinancingDataSource source;
  @override
  Future<Result<FinancingData>> load() => guard(() => source.load());
  @override
  Future<Result<void>> request(
    String kind,
    double amount,
    int count,
    DateTime month,
    String reason,
  ) => guard(() => source.request(kind, amount, count, month, reason));
  @override
  Future<Result<void>> review(String id, String action, String comment) =>
      guard(() => source.review(id, action, comment));
}
