import '../../domain/entities/attendance.dart';

class AttendanceModel extends Attendance {
  AttendanceModel.fromJson(Map<String, dynamic> j)
    : super(
        day: DateTime.parse(j['work_date'] as String),
        checkIn: DateTime.parse(j['check_in'] as String),
        checkOut: j['check_out'] == null
            ? null
            : DateTime.parse(j['check_out'] as String),
        status: j['status'] as String,
        source: j['source'] as String? ?? 'app',
      );
}
