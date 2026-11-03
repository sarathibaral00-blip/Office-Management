import '../../../../core/error/result.dart';
import '../entities/payroll.dart';
import '../repositories/payroll_repository.dart';

class PayrollActions {
  PayrollActions(this.repository);
  final PayrollRepository repository;
  Future<Result<PayrollData>> load(int year) => repository.load(year);
  Future<Result<void>> generate(DateTime month) => repository.generate(month);
  Future<Result<void>> transition(String run, String action) =>
      repository.transition(run, action);
  Future<Result<void>> salary(String employee, Map<String, Object?> values) =>
      repository.salary(employee, values);
  Future<Result<void>> adjust(
    String id,
    double bonus,
    double extra,
    String reason,
  ) => repository.adjust(id, bonus, extra, reason);
  Future<Result<void>> payslip(String id, bool share) =>
      repository.payslip(id, share);
  Future<Result<void>> bank(String run) => repository.bank(run);
}
