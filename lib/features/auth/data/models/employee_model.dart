import '../../domain/entities/employee.dart';

class EmployeeModel extends Employee {
  EmployeeModel.fromJson(Map<String, dynamic> j)
    : super(
        id: j['id'] as String,
        name: j['full_name'] as String? ?? '',
        role: j['role'] as String,
        active: j['is_active'] as bool,
        code: j['employee_code'] as String? ?? '',
      );
}
