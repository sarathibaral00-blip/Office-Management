import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/notices.dart';
import '../../domain/repositories/notices_repository.dart';
import '../datasources/notices_datasource.dart';

class NoticesRepositoryImpl implements NoticesRepository {
  NoticesRepositoryImpl(this.source);
  final NoticesDataSource source;
  @override
  Future<Result<NoticeData>> load() => guard(() => source.load());
  @override
  Future<Result<void>> save(
    String? id,
    String title,
    String body,
    String? department,
    bool active,
  ) => guard(() => source.save(id, title, body, department, active));
  @override
  Future<Result<void>> read(String id) => guard(() => source.read(id));
}
