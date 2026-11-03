import '../../../../core/error/result.dart';
import '../entities/employee.dart';
import '../repositories/auth_repository.dart';

class AuthActions {
  AuthActions(this.repository);
  final AuthRepository repository;
  Stream<AuthSessionEvent> get changes => repository.changes;
  Future<Result<Employee?>> restore() => repository.restore();
  Future<Result<Employee?>> login(String e, String p) => repository.login(e, p);
  Future<Result<void>> reset(String e) => repository.reset(e);
  Future<Result<void>> logout() => repository.logout();
  Future<Result<void>> password(String p) => repository.password(p);
}
