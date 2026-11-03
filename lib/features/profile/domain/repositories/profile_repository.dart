import '../../../../core/error/result.dart';
import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Result<MyProfile>> load();
  Future<Result<void>> phone(String phone);
  Future<Result<void>> photo();
  Future<Result<void>> password(String password);
}
