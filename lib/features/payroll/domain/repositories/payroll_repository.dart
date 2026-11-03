import '../../../../core/error/result.dart';
import '../entities/payroll.dart';

abstract class PayrollRepository {
  Future<Result<PayrollData>> load(int year);
  Future<Result<void>> generate(DateTime month);
  Future<Result<void>> transition(String run, String action);
  Future<Result<void>> salary(String employee, Map<String, Object?> values);
  Future<Result<void>> adjust(
    String id,
    double bonus,
    double extra,
    String reason,
  );
  Future<Result<void>> payslip(String id, bool share);
  Future<Result<void>> bank(String run);
}
