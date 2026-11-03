import '../../../../core/error/result.dart';
import '../entities/notices.dart';

abstract class NoticesRepository {
  Future<Result<NoticeData>> load();
  Future<Result<void>> save(
    String? id,
    String title,
    String body,
    String? department,
    bool active,
  );
  Future<Result<void>> read(String id);
}
