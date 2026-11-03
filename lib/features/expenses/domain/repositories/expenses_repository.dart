import '../../../../core/error/result.dart';
import '../entities/expenses.dart';

abstract class ExpensesRepository {
  Future<Result<ExpenseData>> load();
  Future<Result<String?>> upload();
  Future<Result<void>> submit(
    String title,
    String category,
    double amount,
    DateTime day,
    String receipt,
  );
  Future<Result<void>> review(String id, String action, String comment);
  Future<Result<void>> receipt(String path);
}
