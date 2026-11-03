import '../../../../core/error/result.dart';
import '../entities/exports.dart';

abstract class ExportsRepository {
  Future<Result<ExportOptions>> load();
  Future<Result<void>> export(
    String kind,
    DateTime start,
    DateTime end,
    String? department,
    String? branch,
    String format,
    bool share,
  );
}
