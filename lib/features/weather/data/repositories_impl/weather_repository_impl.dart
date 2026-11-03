import '../../../../core/error/result.dart';
import '../../domain/entities/weather.dart';
import '../../domain/repositories/weather_repository.dart';
import '../datasources/weather_datasource.dart';

class WeatherRepositoryImpl implements WeatherRepository {
  WeatherRepositoryImpl(this.source);
  final WeatherDataSource source;
  @override
  Future<Result<Weather>> current() async {
    try {
      return Result.success(await source.current());
    } on FormatException catch (e) {
      return Result.failure(Failure(e.message));
    } catch (_) {
      return const Result.failure(
        Failure('Weather unavailable. Tap to retry.'),
      );
    }
  }
}
