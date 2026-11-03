import '../../../../core/error/result.dart';
import '../entities/fallback.dart';
import '../repositories/support_repository.dart';

class SupportActions {
  SupportActions(this.repository);
  final SupportRepository repository;
  Future<Result<SupportSnapshot>> snapshot() => repository.snapshot();
  Future<Result<SupportRecord?>> record(String employee, DateTime day) =>
      repository.record(employee, day);
  Future<Result<RecordPage>> report(DateTime month, int offset) =>
      repository.report(month, offset);
  Future<Result<SupportOutcome>> manual(ManualSubmission s) =>
      repository.manual(s);
  Future<Result<SupportOutcome>> manage(
    String action,
    Map<String, Object?> data,
  ) => repository.manage(action, data);
  DevicePairing? get pairing => repository.pairing;
  void clearPairing() => repository.clearPairing();
  Future<Result<void>> devicePunch(DeviceSubmission s) =>
      repository.devicePunch(s);
}
