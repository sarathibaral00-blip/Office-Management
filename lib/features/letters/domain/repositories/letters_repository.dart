import '../../../../core/error/result.dart';
import '../entities/letters.dart';

abstract class LettersRepository {
  Future<Result<LetterData>> load();
  Future<Result<void>> issue(String employee, String kind, String purpose);
  Future<Result<void>> export(String id, bool share);
}
