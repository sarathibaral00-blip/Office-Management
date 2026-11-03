import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/corrections.dart';
import '../../domain/repositories/corrections_repository.dart';
import '../datasources/corrections_datasource.dart';

class CorrectionsRepositoryImpl implements CorrectionsRepository {
  CorrectionsRepositoryImpl(this.source);
  final CorrectionsDataSource source;
  @override
  Future<Result<CorrectionData>> load(int year) =>
      guard(() => source.load(year));
  @override
  Future<Result<void>> request(
    String attendance,
    DateTime checkIn,
    DateTime? checkOut,
    String reason,
  ) => guard(() => source.request(attendance, checkIn, checkOut, reason));
  @override
  Future<Result<void>> review(String id, bool approve, String comment) =>
      guard(() => source.review(id, approve, comment));
}
