import '../../../../core/error/result.dart';
import '../entities/notifications.dart';

abstract class NotificationsRepository {
  Future<Result<InboxData>> load();
  Future<Result<void>> read(String? id);
}
