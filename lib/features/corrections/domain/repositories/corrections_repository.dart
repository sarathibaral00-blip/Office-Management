import '../../../../core/error/result.dart';
import '../entities/corrections.dart';

abstract class CorrectionsRepository {
  Future<Result<CorrectionData>> load(int year);
  Future<Result<void>> request(
    String attendance,
    DateTime checkIn,
    DateTime? checkOut,
    String reason,
  );
  Future<Result<void>> review(String id, bool approve, String comment);
}
