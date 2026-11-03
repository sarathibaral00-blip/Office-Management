import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/features/weather/data/datasources/weather_datasource.dart';
import 'package:hr_management/features/weather/data/repositories_impl/weather_repository_impl.dart';
import 'package:hr_management/features/weather/domain/entities/weather.dart';
import 'package:hr_management/features/weather/domain/repositories/weather_repository.dart';
import 'package:hr_management/features/weather/domain/usecases/get_weather.dart';
import 'package:hr_management/features/weather/presentation/bloc/weather_cubit.dart';

void _expect(bool value, String reason) {
  if (!value) throw StateError(reason);
}

class _WeatherRepository implements WeatherRepository {
  final pending = Completer<Result<Weather>>();
  int calls = 0;
  @override
  Future<Result<Weather>> current() {
    calls++;
    return pending.future;
  }
}

final weatherScenarios = <String, Future<void> Function()>{
  'Weather request sends no credentials and caches a valid Celsius reading':
      () async {
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          _expect(
            request.url.host == 'api.open-meteo.com',
            'Wrong weather endpoint',
          );
          _expect(
            !request.headers.containsKey('authorization') &&
                !request.headers.containsKey('apikey'),
            'Credentials leaked to weather service',
          );
          _expect(
            request.url.queryParameters['temperature_unit'] == 'celsius',
            'Wrong temperature unit',
          );
          return http.Response(
            jsonEncode({
              'current': {
                'temperature_2m': 28.4,
                'weather_code': 2,
                'is_day': 1,
                'time': 1793000000,
              },
            }),
            200,
          );
        });
        final source = WeatherDataSource(client);
        final first = await source.current(), second = await source.current();
        _expect(
          first.celsius == 28.4 &&
              first.condition == 'Partly cloudy' &&
              first == second &&
              calls == 1,
          'Wrong weather or cache behavior',
        );
        client.close();
      },
  'Weather service failure returns a friendly failure without invented temperature':
      () async {
        final client = MockClient(
          (_) async => http.Response('upstream failure', 503),
        );
        final result = await WeatherRepositoryImpl(
          WeatherDataSource(client),
        ).current();
        _expect(
          result.value == null &&
              result.failure!.message.contains('Weather unavailable'),
          'Weather failure fabricated a reading',
        );
        client.close();
      },
  'Malformed weather data is rejected without affecting other features':
      () async {
        final client = MockClient(
          (_) async =>
              http.Response('{"current":{"temperature_2m":null}}', 200),
        );
        final result = await WeatherRepositoryImpl(
          WeatherDataSource(client),
        ).current();
        _expect(
          result.failure != null && result.value == null,
          'Malformed weather accepted',
        );
        client.close();
      },
  'Weather refresh submits once while pending and releases loading after failure':
      () async {
        final repo = _WeatherRepository();
        final cubit = WeatherCubit(GetWeather(repo));
        final first = cubit.load();
        await cubit.load();
        _expect(repo.calls == 1, 'Duplicate weather request');
        repo.pending.complete(
          const Result.failure(Failure('Weather unavailable. Tap to retry.')),
        );
        await first;
        _expect(
          cubit.state.status == LoadStatus.failure && cubit.state.data == null,
          'Weather failure state lost',
        );
        await cubit.close();
      },
};
