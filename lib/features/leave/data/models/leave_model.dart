import '../../domain/entities/leave.dart';

class LeaveModel extends LeaveEntry {
  LeaveModel.fromJson(Map<String, dynamic> j, String who)
    : super(
        id: j['id'] as String,
        employee: j['employee_id'] as String,
        name: (j['profiles'] as Map?)?['full_name'] as String? ?? 'Employee',
        type: j['leave_type_id'] as String,
        start: DateTime.parse(j['starts_on'] as String),
        end: DateTime.parse(j['ends_on'] as String),
        status: j['status'] as String,
        reason: j['reason'] as String,
        mine: j['employee_id'] == who,
        half: j['is_half_day'] as bool,
        period: j['half_day_period'] as String?,
        comment: j['review_comment'] as String?,
        days: (j['requested_days'] as num? ?? 0).toDouble(),
      );
}
