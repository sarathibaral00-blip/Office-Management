import '../../domain/entities/notifications.dart';

class InboxModel extends InboxItem {
  InboxModel.fromJson(Map<String, dynamic> j)
    : super(
        j['id'] as String,
        j['title'] as String,
        j['body'] as String,
        j['kind'] as String,
        DateTime.parse(j['created_at'] as String),
        j['read_at'] != null,
      );
}
