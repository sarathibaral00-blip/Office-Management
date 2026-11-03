import '../../../../core/error/result.dart';
import '../entities/preferences.dart';

abstract class PreferencesRepository {
  Future<Result<UiPreferences>> load();
  Future<Result<void>> save(UiPreferences preferences);
}
