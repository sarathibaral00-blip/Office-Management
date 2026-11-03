import '../../../../core/error/result.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class ProfileActions {
  ProfileActions(this.repository);
  final ProfileRepository repository;
  Future<Result<MyProfile>> load() => repository.load();
  Future<Result<void>> phone(String phone) => repository.phone(phone);
  Future<Result<void>> photo() => repository.photo();
  Future<Result<void>> password(String password) =>
      repository.password(password);
}
