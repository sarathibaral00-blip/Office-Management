import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this.source);
  final SettingsDataSource source;
  @override
  Future<Result<SettingsData>> load(int auditOffset) =>
      guard(() => source.load(auditOffset));
  @override
  Future<Result<void>> company(Map<String, Object?> data) =>
      guard(() => source.company(data));
  @override
  Future<Result<void>> asset(String kind) => guard(() => source.asset(kind));
  @override
  Future<Result<void>> shift(String? id, Map<String, Object?> data) =>
      guard(() => source.shift(id, data));
  @override
  Future<Result<void>> permission(String role, String key, bool enabled) =>
      guard(() => source.permission(role, key, enabled));
}
