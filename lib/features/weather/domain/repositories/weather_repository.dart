import '../../../../core/error/result.dart';
import '../entities/weather.dart';

abstract class WeatherRepository {
  Future<Result<Weather>> current();
}
