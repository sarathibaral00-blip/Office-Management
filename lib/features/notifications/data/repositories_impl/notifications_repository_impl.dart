import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/notifications.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this.source);
  final NotificationsDataSource source;
  @override
  Future<Result<InboxData>> load() => guard(() => source.load());
  @override
  Future<Result<void>> read(String? id) => guard(() => source.read(id));
}
