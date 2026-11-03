import '../../../../core/error/result.dart';
import '../entities/settings.dart';
import '../repositories/settings_repository.dart';

class SettingsActions {
  SettingsActions(this.repository);
  final SettingsRepository repository;
  Future<Result<SettingsData>> load(int auditOffset) =>
      repository.load(auditOffset);
  Future<Result<void>> company(Map<String, Object?> data) =>
      repository.company(data);
  Future<Result<void>> asset(String kind) => repository.asset(kind);
  Future<Result<void>> shift(String? id, Map<String, Object?> data) =>
      repository.shift(id, data);
  Future<Result<void>> permission(String role, String key, bool enabled) =>
      repository.permission(role, key, enabled);
}
