import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/weather.dart';
import '../models/weather_model.dart';

class WeatherDataSource {
  WeatherDataSource(this.client);
  final http.Client client;
  Weather? _cached;
  DateTime? _fetchedAt;
  static const city = String.fromEnvironment(
    'WEATHER_CITY',
    defaultValue: 'Dhaka',
  );
  static const latitude = String.fromEnvironment(
    'WEATHER_LATITUDE',
    defaultValue: '23.8103',
  );
  static const longitude = String.fromEnvironment(
    'WEATHER_LONGITUDE',
    defaultValue: '90.4125',
  );

  Future<Weather> current() async {
    if (_cached != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(minutes: 10)) {
      return _cached!;
    }
    final lat = double.tryParse(latitude), lon = double.tryParse(longitude);
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      throw const FormatException(
        'Weather location is not configured correctly.',
      );
    }
    // No Auth headers, Supabase keys, employee data or GPS are sent here.
    final response = await client
        .get(
          Uri.https('api.open-meteo.com', '/v1/forecast', {
            'latitude': latitude,
            'longitude': longitude,
            'current': 'temperature_2m,weather_code,is_day',
            'temperature_unit': 'celsius',
            'timeformat': 'unixtime',
            'forecast_days': '1',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const FormatException('Weather unavailable. Tap to retry.');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Weather unavailable. Tap to retry.');
    }
    final weather = WeatherModel.fromJson(data, city);
    _cached = weather;
    _fetchedAt = DateTime.now();
    return weather;
  }
}
