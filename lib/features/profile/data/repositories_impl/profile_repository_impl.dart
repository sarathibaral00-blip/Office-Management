import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this.source);
  final ProfileDataSource source;
  @override
  Future<Result<MyProfile>> load() => guard(() => source.load());
  @override
  Future<Result<void>> phone(String phone) => guard(() => source.phone(phone));
  @override
  Future<Result<void>> photo() => guard(() => source.photo());
  @override
  Future<Result<void>> password(String password) =>
      guard(() => source.password(password));
}
