import '../../domain/entities/weather.dart';

class WeatherModel {
  static Weather fromJson(Map<String, dynamic> json, String city) {
    final current = json['current'];
    if (current is! Map ||
        current['temperature_2m'] is! num ||
        current['weather_code'] is! num ||
        current['time'] is! num ||
        ![0, 1].contains(current['is_day'])) {
      throw const FormatException('Weather unavailable. Tap to retry.');
    }
    final degrees = (current['temperature_2m'] as num).toDouble();
    if (!degrees.isFinite) {
      throw const FormatException('Weather unavailable. Tap to retry.');
    }
    return Weather(
      city: city,
      celsius: degrees,
      code: (current['weather_code'] as num).toInt(),
      isDay: current['is_day'] == 1,
      observedAt: DateTime.fromMillisecondsSinceEpoch(
        (current['time'] as num).toInt() * 1000,
        isUtc: true,
      ),
    );
  }
}
