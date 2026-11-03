import '../../../../core/error/result.dart';
import '../entities/holidays.dart';

abstract class HolidaysRepository {
  Future<Result<HolidayData>> load(int year);
  Future<Result<void>> save(
    String? id,
    String name,
    DateTime day,
    String? branch,
    bool active,
  );
}
