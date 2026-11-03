import 'package:equatable/equatable.dart';

class Employee extends Equatable {
  const Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    this.code = '',
  });
  final String id, name, role;
  final String code;
  final bool active;
  bool get isAdmin => role == 'hr' || role == 'super_admin';
  bool get isEmployee => role == 'employee';
  @override
  List<Object?> get props => [id, name, role, active, code];
}
