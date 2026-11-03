import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/documents.dart';
import '../../domain/repositories/documents_repository.dart';
import '../datasources/documents_datasource.dart';

class DocumentsRepositoryImpl implements DocumentsRepository {
  DocumentsRepositoryImpl(this.source);
  final DocumentsDataSource source;
  @override
  Future<Result<DocumentData>> load() => guard(() => source.load());
  @override
  Future<Result<void>> upload(String employee, String kind, String title) =>
      guard(() => source.upload(employee, kind, title));
  @override
  Future<Result<void>> download(String path, String title) =>
      guard(() => source.download(path, title));
}
