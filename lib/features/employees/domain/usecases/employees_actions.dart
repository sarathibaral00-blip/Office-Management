import '../../../../core/error/result.dart';
import '../../../../core/domain/page_result.dart';
import '../entities/employees.dart';
import '../repositories/employees_repository.dart';

class EmployeesActions {
  EmployeesActions(this.repository);
  final EmployeesRepository repository;
  Future<Result<Directory>> list(
    String search,
    String? department,
    String? branch,
    bool? active,
    int offset,
  ) => repository.list(search, department, branch, active, offset);
  Future<Result<Choice>> createDepartment(String name) =>
      repository.createDepartment(name);
  Future<Result<Staff>> detail(String id) => repository.detail(id);
  Future<Result<void>> create(Map<String, Object?> data) =>
      repository.create(data);
  Future<Result<void>> update(String id, Map<String, Object?> data) =>
      repository.update(id, data);
  Future<Result<void>> pin(String id, String pin) => repository.pin(id, pin);
}
