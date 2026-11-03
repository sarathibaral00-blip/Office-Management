import '../../../../core/error/result.dart';
import '../entities/holidays.dart';
import '../repositories/holidays_repository.dart';

class HolidaysActions {
  HolidaysActions(this.repository);
  final HolidaysRepository repository;
  Future<Result<HolidayData>> load(int year) => repository.load(year);
  Future<Result<void>> save(
    String? id,
    String name,
    DateTime day,
    String? branch,
    bool active,
  ) => repository.save(id, name, day, branch, active);
}
