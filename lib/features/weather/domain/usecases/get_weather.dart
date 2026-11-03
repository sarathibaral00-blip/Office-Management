import '../repositories/weather_repository.dart';
import '../entities/weather.dart';
import '../../../../core/error/result.dart';

class GetWeather {
  const GetWeather(this.repository);
  final WeatherRepository repository;
  Future<Result<Weather>> call() => repository.current();
}
