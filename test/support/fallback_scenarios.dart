import 'dart:async';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/features/attendance/data/models/attendance_model.dart';
import 'package:hr_management/features/attendance_support/domain/entities/fallback.dart';
import 'package:hr_management/features/attendance_support/domain/repositories/support_repository.dart';
import 'package:hr_management/features/attendance_support/domain/usecases/support_actions.dart';
import 'package:hr_management/features/attendance_support/presentation/bloc/support_cubit.dart';
import 'scenarios.dart' show expectEqual;

class FakeSupport implements SupportRepository {
  @override
  DevicePairing? pairing;
  int punches = 0;
  final punchResponse = Completer<Result<void>>();
  final reportRequests = <Completer<Result<RecordPage>>>[];
  SupportOutcome manualOutcome = const SupportOutcome();
  static const snapshotData = SupportSnapshot([], [], [], [], 3);
  @override
  Future<Result<SupportSnapshot>> snapshot() async =>
      const Result.success(snapshotData);
  @override
  Future<Result<SupportRecord?>> record(String employee, DateTime day) async =>
      const Result.success(null);
  @override
  Future<Result<RecordPage>> report(DateTime month, int offset) {
    final c = Completer<Result<RecordPage>>();
    reportRequests.add(c);
    return c.future;
  }

  @override
  Future<Result<SupportOutcome>> manual(ManualSubmission submission) async =>
      Result.success(manualOutcome);
  @override
  Future<Result<SupportOutcome>> manage(
    String action,
    Map<String, Object?> data,
  ) async => const Result.success(SupportOutcome());
  @override
  void clearPairing() {
    pairing = null;
  }

  @override
  Future<Result<void>> devicePunch(DeviceSubmission submission) {
    punches++;
    return punchResponse.future;
  }
}

SupportRecord record(String id) => SupportRecord(
  id: id,
  employeeId: 'employee',
  day: DateTime(2026, 10, 20),
  checkIn: DateTime.utc(2026, 10, 20, 3),
  source: 'manual',
  status: 'present',
);
final Map<String, Future<void> Function()> fallbackScenarios = {
  'Existing attendance JSON without source remains app attendance': () async {
    final a = AttendanceModel.fromJson({
      'work_date': '2026-10-20',
      'check_in': '2026-10-20T03:00:00Z',
      'status': 'present',
    });
    expectEqual(a.source, 'app');
    final manual = AttendanceModel.fromJson({
      'work_date': '2026-10-20',
      'check_in': '2026-10-20T03:00:00Z',
      'status': 'present',
      'source': 'manual',
    });
    expectEqual(manual.source, 'manual');
  },
  'Expired approvals fail before submission and clear in-memory pairing':
      () async {
        final repository = FakeSupport()
          ..pairing = DevicePairing(
            'id',
            'Temporary',
            'temporary',
            DateTime.now().subtract(const Duration(seconds: 1)),
          );
        final cubit = KioskCubit(SupportActions(repository));
        await cubit.punch(
          const DeviceSubmission(
            action: 'check_in',
            code: 'EMP-000001',
            pin: '123456',
          ),
        );
        expectEqual(repository.punches, 0);
        expectEqual(repository.pairing, null);
        expectEqual(cubit.state.status, LoadStatus.failure);
        await cubit.close();
      },
  'Kiosk double taps submit once and states do not retain entered PIN':
      () async {
        final repository = FakeSupport()
          ..pairing = const DevicePairing('id', 'Office', 'kiosk', null);
        final cubit = KioskCubit(SupportActions(repository));
        final first = cubit.punch(
          const DeviceSubmission(
            action: 'check_in',
            code: 'EMP-000001',
            pin: '123456',
          ),
        );
        await cubit.punch(
          const DeviceSubmission(
            action: 'check_in',
            code: 'EMP-000001',
            pin: '123456',
          ),
        );
        expectEqual(repository.punches, 1);
        expectEqual(cubit.state.toString().contains('123456'), false);
        repository.punchResponse.complete(
          const Result.failure(
            Failure('Invalid Employee ID or PIN. Ask HR to reset it if locked'),
          ),
        );
        await first;
        expectEqual(cubit.state.status, LoadStatus.failure);
        expectEqual(cubit.state.toString().contains('123456'), false);
        await cubit.close();
      },
  'Manual limit warnings report a successful save and HR notification':
      () async {
        final repository = FakeSupport()
          ..manualOutcome = const SupportOutcome(
            exceeded: true,
            count: 4,
            limit: 3,
          );
        final cubit = ManualCubit(SupportActions(repository));
        await cubit.load();
        final ok = await cubit.submit(
          ManualSubmission(
            employeeId: 'employee',
            checkIn: DateTime.now(),
            reason: 'Forgot phone',
          ),
        );
        expectEqual(ok, true);
        expectEqual(cubit.state.message!.contains('HR was notified'), true);
        expectEqual(cubit.state.snapshot, FakeSupport.snapshotData);
        await cubit.close();
      },
  'Setting a PIN preserves an already paired terminal': () async {
    final repository = FakeSupport()
      ..pairing = const DevicePairing('id', 'Office', 'kiosk', null);
    final cubit = DevicesCubit(SupportActions(repository));
    await cubit.load();
    await cubit.manage('set_pin', {'employee_id': 'employee', 'pin': '123456'});
    expectEqual(cubit.state.paired, true);
    expectEqual(cubit.state.toString().contains('123456'), false);
    await cubit.close();
  },
  'Old report pages cannot append after switching months': () async {
    final repository = FakeSupport();
    final cubit = ReportCubit(SupportActions(repository));
    final first = cubit.load(DateTime(2026, 9));
    await Future<void>.delayed(Duration.zero);
    repository.reportRequests[0].complete(
      Result.success(RecordPage([record('september')], true)),
    );
    await first;
    final more = cubit.more();
    final october = cubit.load(DateTime(2026, 10));
    await Future<void>.delayed(Duration.zero);
    repository.reportRequests[2].complete(
      Result.success(RecordPage([record('october')], false)),
    );
    await october;
    repository.reportRequests[1].complete(
      Result.success(RecordPage([record('old-page')], false)),
    );
    await more;
    expectEqual(cubit.state.records.length, 1);
    expectEqual(cubit.state.records.single.id, 'october');
    await cubit.close();
  },
};
