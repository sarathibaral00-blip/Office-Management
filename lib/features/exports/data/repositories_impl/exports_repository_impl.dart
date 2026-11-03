import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/exports.dart';
import '../../domain/repositories/exports_repository.dart';
import '../datasources/exports_datasource.dart';

class ExportsRepositoryImpl implements ExportsRepository {
  ExportsRepositoryImpl(this.source);
  final ExportsDataSource source;
  @override
  Future<Result<ExportOptions>> load() => guard(() => source.load());
  @override
  Future<Result<void>> export(
    String kind,
    DateTime start,
    DateTime end,
    String? department,
    String? branch,
    String format,
    bool share,
  ) => guard(
    () => source.export(kind, start, end, department, branch, format, share),
  );
}
