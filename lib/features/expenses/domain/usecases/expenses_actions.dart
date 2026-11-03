import '../../../../core/error/result.dart';
import '../entities/expenses.dart';
import '../repositories/expenses_repository.dart';

class ExpensesActions {
  ExpensesActions(this.repository);
  final ExpensesRepository repository;
  Future<Result<ExpenseData>> load() => repository.load();
  Future<Result<String?>> upload() => repository.upload();
  Future<Result<void>> submit(
    String title,
    String category,
    double amount,
    DateTime day,
    String receipt,
  ) => repository.submit(title, category, amount, day, receipt);
  Future<Result<void>> review(String id, String action, String comment) =>
      repository.review(id, action, comment);
  Future<Result<void>> receipt(String path) => repository.receipt(path);
}
