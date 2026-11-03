import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/holidays.dart';
import '../../domain/repositories/holidays_repository.dart';
import '../datasources/holidays_datasource.dart';

class HolidaysRepositoryImpl implements HolidaysRepository {
  HolidaysRepositoryImpl(this.source);
  final HolidaysDataSource source;
  @override
  Future<Result<HolidayData>> load(int year) => guard(() => source.load(year));
  @override
  Future<Result<void>> save(
    String? id,
    String name,
    DateTime day,
    String? branch,
    bool active,
  ) => guard(() => source.save(id, name, day, branch, active));
}
