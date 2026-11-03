import '../../../../core/error/result.dart';
import '../../../../core/domain/page_result.dart';
import '../entities/employees.dart';

abstract class EmployeesRepository {
  Future<Result<Directory>> list(
    String search,
    String? department,
    String? branch,
    bool? active,
    int offset,
  );
  Future<Result<Choice>> createDepartment(String name);
  Future<Result<Staff>> detail(String id);
  Future<Result<void>> create(Map<String, Object?> data);
  Future<Result<void>> update(String id, Map<String, Object?> data);
  Future<Result<void>> pin(String id, String pin);
}
