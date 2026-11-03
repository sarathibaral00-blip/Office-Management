import '../../../../core/error/result.dart';
import '../entities/corrections.dart';
import '../repositories/corrections_repository.dart';

class CorrectionsActions {
  CorrectionsActions(this.repository);
  final CorrectionsRepository repository;
  Future<Result<CorrectionData>> load(int year) => repository.load(year);
  Future<Result<void>> request(
    String attendance,
    DateTime checkIn,
    DateTime? checkOut,
    String reason,
  ) => repository.request(attendance, checkIn, checkOut, reason);
  Future<Result<void>> review(String id, bool approve, String comment) =>
      repository.review(id, approve, comment);
}
