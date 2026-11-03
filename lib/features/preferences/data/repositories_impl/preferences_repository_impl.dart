import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/preferences.dart';
import '../../domain/repositories/preferences_repository.dart';
import '../datasources/preferences_datasource.dart';

class PreferencesRepositoryImpl implements PreferencesRepository {
  PreferencesRepositoryImpl(this.source);
  final PreferencesDataSource source;
  @override
  Future<Result<UiPreferences>> load() => guard(() => source.load());
  @override
  Future<Result<void>> save(UiPreferences preferences) =>
      guard(() => source.save(preferences));
}
