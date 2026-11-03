import '../../../../core/error/result.dart';
import '../entities/exports.dart';
import '../repositories/exports_repository.dart';

class ExportsActions {
  ExportsActions(this.repository);
  final ExportsRepository repository;
  Future<Result<ExportOptions>> load() => repository.load();
  Future<Result<void>> export(
    String kind,
    DateTime start,
    DateTime end,
    String? department,
    String? branch,
    String format,
    bool share,
  ) => repository.export(kind, start, end, department, branch, format, share);
}
