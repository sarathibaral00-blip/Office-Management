import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.source);
  final AuthDataSource source;
  Future<Result<T>> guard<T>(Future<T> Function() work) async {
    try {
      return Result.success(await work());
    } on AuthException catch (e) {
      return Result.failure(Failure(e.message));
    } catch (_) {
      return const Result.failure(
        Failure('Could not connect. Please try again.'),
      );
    }
  }

  @override
  Stream<AuthSessionEvent> get changes => source.changes;
  @override
  Future<Result<Employee?>> restore() => guard(source.restore);
  @override
  Future<Result<Employee?>> login(String e, String p) =>
      guard(() => source.login(e, p));
  @override
  Future<Result<void>> reset(String e) => guard(() => source.reset(e));
  @override
  Future<Result<void>> logout() => guard(source.logout);
  @override
  Future<Result<void>> password(String p) => guard(() => source.password(p));
}
