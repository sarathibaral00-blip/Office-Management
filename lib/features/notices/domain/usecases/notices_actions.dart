import '../../../../core/error/result.dart';
import '../entities/notices.dart';
import '../repositories/notices_repository.dart';

class NoticesActions {
  NoticesActions(this.repository);
  final NoticesRepository repository;
  Future<Result<NoticeData>> load() => repository.load();
  Future<Result<void>> save(
    String? id,
    String title,
    String body,
    String? department,
    bool active,
  ) => repository.save(id, title, body, department, active);
  Future<Result<void>> read(String id) => repository.read(id);
}
