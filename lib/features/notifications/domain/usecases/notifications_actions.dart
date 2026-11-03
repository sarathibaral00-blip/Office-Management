import '../../../../core/error/result.dart';
import '../entities/notifications.dart';
import '../repositories/notifications_repository.dart';

class NotificationsActions {
  NotificationsActions(this.repository);
  final NotificationsRepository repository;
  Future<Result<InboxData>> load() => repository.load();
  Future<Result<void>> read(String? id) => repository.read(id);
}
