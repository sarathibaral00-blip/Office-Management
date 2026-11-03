import 'package:equatable/equatable.dart';
import '../../../../core/domain/page_result.dart';

class Staff extends Equatable {
  const Staff({
    required this.id,
    required this.name,
    required this.code,
    required this.email,
    required this.role,
    required this.salary,
    required this.active,
    this.department,
    this.branch,
    this.manager,
    this.shift,
    this.designation,
  });
  final String id, name, code, email, role;
  final double salary;
  final bool active;
  final String? department, branch, manager, shift, designation;
  @override
  List<Object?> get props => [
    id,
    name,
    code,
    email,
    role,
    salary,
    active,
    department,
    branch,
    manager,
    designation,
    shift,
  ];
}

class Directory extends Equatable {
  const Directory(
    this.page,
    this.departments,
    this.branches,
    this.managers,
    this.shifts,
  );
  final PageResult<Staff> page;
  final List<Choice> departments, branches, managers, shifts;
  @override
  List<Object?> get props => [page, departments, branches, managers, shifts];
}
