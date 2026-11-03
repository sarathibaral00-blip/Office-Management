import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/expenses.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../datasources/expenses_datasource.dart';

class ExpensesRepositoryImpl implements ExpensesRepository {
  ExpensesRepositoryImpl(this.source);
  final ExpensesDataSource source;
  @override
  Future<Result<ExpenseData>> load() => guard(() => source.load());
  @override
  Future<Result<String?>> upload() => guard(() => source.upload());
  @override
  Future<Result<void>> submit(
    String title,
    String category,
    double amount,
    DateTime day,
    String receipt,
  ) => guard(() => source.submit(title, category, amount, day, receipt));
  @override
  Future<Result<void>> review(String id, String action, String comment) =>
      guard(() => source.review(id, action, comment));
  @override
  Future<Result<void>> receipt(String path) =>
      guard(() => source.receipt(path));
}
