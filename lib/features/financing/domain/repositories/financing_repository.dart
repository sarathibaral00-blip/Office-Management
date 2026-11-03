import '../../../../core/error/result.dart';
import '../entities/financing.dart';

abstract class FinancingRepository {
  Future<Result<FinancingData>> load();
  Future<Result<void>> request(
    String kind,
    double amount,
    int count,
    DateTime month,
    String reason,
  );
  Future<Result<void>> review(String id, String action, String comment);
}
