import '../../../../core/error/result.dart';
import '../entities/employee.dart';

enum AuthSessionEvent { changed, passwordRecovery }

abstract class AuthRepository {
  Stream<AuthSessionEvent> get changes;
  Future<Result<Employee?>> restore();
  Future<Result<Employee?>> login(String email, String password);
  Future<Result<void>> reset(String email);
  Future<Result<void>> logout();
  Future<Result<void>> password(String password);
}
