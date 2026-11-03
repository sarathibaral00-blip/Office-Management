import '../../../../core/error/result.dart';
import '../entities/documents.dart';
import '../repositories/documents_repository.dart';

class DocumentsActions {
  DocumentsActions(this.repository);
  final DocumentsRepository repository;
  Future<Result<DocumentData>> load() => repository.load();
  Future<Result<void>> upload(String employee, String kind, String title) =>
      repository.upload(employee, kind, title);
  Future<Result<void>> download(String path, String title) =>
      repository.download(path, title);
}
