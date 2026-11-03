import '../../domain/entities/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesDataSource {
  PreferencesDataSource();

  Future<UiPreferences> load() async {
    final p = await SharedPreferences.getInstance();
    return UiPreferences(
      language: p.getString('ui.language') == 'bn' ? 'bn' : 'en',
      theme: ['light', 'dark'].contains(p.getString('ui.theme'))
          ? p.getString('ui.theme')!
          : 'system',
    );
  }

  Future<void> save(UiPreferences preferences) async {
    if (!['en', 'bn'].contains(preferences.language) ||
        !['system', 'light', 'dark'].contains(preferences.theme)) {
      throw const FormatException('Invalid display preference.');
    }
    final p = await SharedPreferences.getInstance();
    if (!await p.setString('ui.language', preferences.language) ||
        !await p.setString('ui.theme', preferences.theme)) {
      throw const FormatException('Display preferences could not be saved.');
    }
  }
}
