import '../../../../core/error/result.dart';
import '../entities/fallback.dart';

abstract class SupportRepository {
  Future<Result<SupportSnapshot>> snapshot();
  Future<Result<SupportRecord?>> record(String employee, DateTime day);
  Future<Result<RecordPage>> report(DateTime month, int offset);
  Future<Result<SupportOutcome>> manual(ManualSubmission submission);
  Future<Result<SupportOutcome>> manage(
    String action,
    Map<String, Object?> data,
  );
  DevicePairing? get pairing;
  void clearPairing();
  Future<Result<void>> devicePunch(DeviceSubmission submission);
}
