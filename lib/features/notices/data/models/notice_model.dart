import '../../domain/entities/notices.dart';

class NoticeModel extends Notice {
  NoticeModel.fromJson(Map<String, dynamic> j, List<Map<String, dynamic>> reads)
    : super(
        j['id'] as String,
        j['title'] as String,
        j['body'] as String,
        DateTime.parse(j['published_at'] as String),
        j['department_id'] as String?,
        !reads.any(
          (r) =>
              r['announcement_id'] == j['id'] &&
              !DateTime.parse(
                r['read_at'] as String,
              ).isBefore(DateTime.parse(j['updated_at'] as String)),
        ),
      );
}
