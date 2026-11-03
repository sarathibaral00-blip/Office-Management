import '../../../../core/error/result.dart';
import '../entities/preferences.dart';
import '../repositories/preferences_repository.dart';

class PreferencesActions {
  PreferencesActions(this.repository);
  final PreferencesRepository repository;
  Future<Result<UiPreferences>> load() => repository.load();
  Future<Result<void>> save(UiPreferences preferences) =>
      repository.save(preferences);
}
