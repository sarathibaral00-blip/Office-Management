import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/letters.dart';
import '../../domain/repositories/letters_repository.dart';
import '../datasources/letters_datasource.dart';

class LettersRepositoryImpl implements LettersRepository {
  LettersRepositoryImpl(this.source);
  final LettersDataSource source;
  @override
  Future<Result<LetterData>> load() => guard(() => source.load());
  @override
  Future<Result<void>> issue(String employee, String kind, String purpose) =>
      guard(() => source.issue(employee, kind, purpose));
  @override
  Future<Result<void>> export(String id, bool share) =>
      guard(() => source.export(id, share));
}
