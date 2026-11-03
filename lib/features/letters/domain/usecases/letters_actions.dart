import '../../../../core/error/result.dart';
import '../entities/letters.dart';
import '../repositories/letters_repository.dart';

class LettersActions {
  LettersActions(this.repository);
  final LettersRepository repository;
  Future<Result<LetterData>> load() => repository.load();
  Future<Result<void>> issue(String employee, String kind, String purpose) =>
      repository.issue(employee, kind, purpose);
  Future<Result<void>> export(String id, bool share) =>
      repository.export(id, share);
}
