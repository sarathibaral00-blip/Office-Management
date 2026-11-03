import '../../domain/entities/holidays.dart';

class HolidayModel extends Holiday {
  HolidayModel.fromJson(Map<String, dynamic> j)
    : super(
        j['id'] as String,
        j['name'] as String,
        DateTime.parse(j['holiday_date'] as String),
        j['branch_id'] as String?,
      );
}
