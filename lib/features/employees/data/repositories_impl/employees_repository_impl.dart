import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../../../core/domain/page_result.dart';
import '../../domain/entities/employees.dart';
import '../../domain/repositories/employees_repository.dart';
import '../datasources/employees_datasource.dart';

class EmployeesRepositoryImpl implements EmployeesRepository {
  EmployeesRepositoryImpl(this.source);
  final EmployeesDataSource source;
  @override
  Future<Result<Directory>> list(
    String search,
    String? department,
    String? branch,
    bool? active,
    int offset,
  ) => guard(() => source.list(search, department, branch, active, offset));
  @override
  Future<Result<Choice>> createDepartment(String name) =>
      guard(() => source.createDepartment(name));
  @override
  Future<Result<Staff>> detail(String id) => guard(() => source.detail(id));
  @override
  Future<Result<void>> create(Map<String, Object?> data) =>
      guard(() => source.create(data));
  @override
  Future<Result<void>> update(String id, Map<String, Object?> data) =>
      guard(() => source.update(id, data));
  @override
  Future<Result<void>> pin(String id, String pin) =>
      guard(() => source.pin(id, pin));
}
