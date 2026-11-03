import 'package:equatable/equatable.dart';

class UiPreferences extends Equatable {
  const UiPreferences({this.language = 'en', this.theme = 'system'});
  final String language, theme;
  @override
  List<Object?> get props => [language, theme];
}
