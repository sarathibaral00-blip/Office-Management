import '../../domain/entities/employees.dart';

class StaffModel extends Staff {
  StaffModel.fromJson(Map<String, dynamic> j)
    : super(
        id: j['id'] as String,
        name: j['full_name'] as String,
        code: j['employee_code'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: j['role'] as String,
        salary: (j['salary'] as num).toDouble(),
        active: j['is_active'] as bool,
        department: j['department_id'] as String?,
        branch: j['branch_id'] as String?,
        manager: j['manager_id'] as String?,
        designation: j['designation'] as String?,
        shift: j['shift_id'] as String?,
      );
}
