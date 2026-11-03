import '../../domain/entities/corrections.dart';

class CorrectionModel extends Correction {
  CorrectionModel.fromJson(Map<String, dynamic> j, String who)
    : super(
        j['id'] as String,
        j['employee_id'] as String,
        (j['profiles'] as Map?)?['full_name'] as String? ?? 'Employee',
        j['employee_id'] == who,
        DateTime.parse(j['requested_check_in'] as String),
        j['requested_check_out'] == null
            ? null
            : DateTime.parse(j['requested_check_out'] as String),
        j['reason'] as String,
        j['status'] as String,
        j['review_comment'] as String?,
      );
}
