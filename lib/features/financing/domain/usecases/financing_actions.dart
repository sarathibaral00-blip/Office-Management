import '../../../../core/error/result.dart';
import '../entities/financing.dart';
import '../repositories/financing_repository.dart';

class FinancingActions {
  FinancingActions(this.repository);
  final FinancingRepository repository;
  Future<Result<FinancingData>> load() => repository.load();
  Future<Result<void>> request(
    String kind,
    double amount,
    int count,
    DateTime month,
    String reason,
  ) => repository.request(kind, amount, count, month, reason);
  Future<Result<void>> review(String id, String action, String comment) =>
      repository.review(id, action, comment);
}
