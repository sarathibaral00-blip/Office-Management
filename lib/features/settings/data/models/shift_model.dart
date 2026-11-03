import '../../domain/entities/settings.dart';

class ShiftModel extends ShiftSchedule {
  ShiftModel.fromJson(Map<String, dynamic> j)
    : super(
        j['id'] as String,
        j['name'] as String,
        (j['starts_at'] as String).substring(0, 5),
        (j['ends_at'] as String).substring(0, 5),
        j['grace_minutes'] as int,
        List<int>.from(j['work_days'] as List),
        j['is_default'] as bool,
      );
}
