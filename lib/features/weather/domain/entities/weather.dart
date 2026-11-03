import 'package:equatable/equatable.dart';

class Weather extends Equatable {
  const Weather({
    required this.city,
    required this.celsius,
    required this.code,
    required this.isDay,
    required this.observedAt,
  });
  final String city;
  final double celsius;
  final int code;
  final bool isDay;
  final DateTime observedAt;
  String get condition => switch (code) {
    0 => isDay ? 'Clear sky' : 'Clear night',
    1 || 2 => 'Partly cloudy',
    3 => 'Overcast',
    45 || 48 => 'Foggy',
    >= 51 && <= 67 => 'Rainy',
    >= 71 && <= 77 => 'Snowy',
    >= 80 && <= 82 => 'Showers',
    85 || 86 => 'Snow showers',
    >= 95 && <= 99 => 'Thunderstorm',
    _ => 'Weather',
  };
  @override
  List<Object?> get props => [city, celsius, code, isDay, observedAt];
}
