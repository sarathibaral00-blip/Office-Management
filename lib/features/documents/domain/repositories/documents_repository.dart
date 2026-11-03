import '../../../../core/error/result.dart';
import '../entities/documents.dart';

abstract class DocumentsRepository {
  Future<Result<DocumentData>> load();
  Future<Result<void>> upload(String employee, String kind, String title);
  Future<Result<void>> download(String path, String title);
}
