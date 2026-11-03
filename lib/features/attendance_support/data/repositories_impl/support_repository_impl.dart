import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/fallback.dart';
import '../../domain/repositories/support_repository.dart';
import '../datasources/support_datasource.dart';

class SupportRepositoryImpl implements SupportRepository {
  SupportRepositoryImpl(this.source);
  final SupportDataSource source;
  @override
  Future<Result<SupportSnapshot>> snapshot() => guard(source.snapshot);
  @override
  Future<Result<SupportRecord?>> record(String employee, DateTime day) =>
      guard(() => source.record(employee, day));
  @override
  Future<Result<RecordPage>> report(DateTime month, int offset) =>
      guard(() => source.report(month, offset));
  @override
  Future<Result<SupportOutcome>> manual(ManualSubmission s) =>
      guard(() => source.manual(s));
  @override
  Future<Result<SupportOutcome>> manage(
    String action,
    Map<String, Object?> data,
  ) => guard(() => source.manage(action, data));
  @override
  DevicePairing? get pairing => source.pairing;
  @override
  void clearPairing() => source.clearPairing();
  @override
  Future<Result<void>> devicePunch(DeviceSubmission s) =>
      guard(() => source.devicePunch(s));
}
