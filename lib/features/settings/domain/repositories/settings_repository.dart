import '../../../../core/error/result.dart';
import '../entities/settings.dart';

abstract class SettingsRepository {
  Future<Result<SettingsData>> load(int auditOffset);
  Future<Result<void>> company(Map<String, Object?> data);
  Future<Result<void>> asset(String kind);
  Future<Result<void>> shift(String? id, Map<String, Object?> data);
  Future<Result<void>> permission(String role, String key, bool enabled);
}
