import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/payroll.dart';
import '../../domain/repositories/payroll_repository.dart';
import '../datasources/payroll_datasource.dart';

class PayrollRepositoryImpl implements PayrollRepository {
  PayrollRepositoryImpl(this.source);
  final PayrollDataSource source;
  @override
  Future<Result<PayrollData>> load(int year) => guard(() => source.load(year));
  @override
  Future<Result<void>> generate(DateTime month) =>
      guard(() => source.generate(month));
  @override
  Future<Result<void>> transition(String run, String action) =>
      guard(() => source.transition(run, action));
  @override
  Future<Result<void>> salary(String employee, Map<String, Object?> values) =>
      guard(() => source.salary(employee, values));
  @override
  Future<Result<void>> adjust(
    String id,
    double bonus,
    double extra,
    String reason,
  ) => guard(() => source.adjust(id, bonus, extra, reason));
  @override
  Future<Result<void>> payslip(String id, bool share) =>
      guard(() => source.payslip(id, share));
  @override
  Future<Result<void>> bank(String run) => guard(() => source.bank(run));
}
