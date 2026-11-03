import 'dart:async';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/features/attendance/domain/entities/attendance.dart';
import 'package:hr_management/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hr_management/features/attendance/domain/usecases/attendance_actions.dart';
import 'package:hr_management/features/attendance/presentation/bloc/attendance_cubit.dart';
import 'package:hr_management/features/auth/domain/entities/employee.dart';
import 'package:hr_management/features/auth/domain/repositories/auth_repository.dart';
import 'package:hr_management/features/auth/domain/usecases/auth_actions.dart';
import 'package:hr_management/features/auth/presentation/bloc/auth_cubit.dart';

class FakeAttendance implements AttendanceRepository {
  final requests = <Completer<Result<WorkMonth>>>[];
  final punchRequest = Completer<Result<void>>();
  int punches = 0;
  @override
  Future<Result<WorkMonth>> month(DateTime? month) {
    final c = Completer<Result<WorkMonth>>();
    requests.add(c);
    return c.future;
  }

  @override
  Future<Result<bool>> network() async => const Result.success(true);
  @override
  Future<Result<void>> punch(String action) {
    punches++;
    return punchRequest.future;
  }
}

class FakeAuth implements AuthRepository {
  final events = StreamController<AuthSessionEvent>.broadcast();
  static const employee = Employee(
    id: 'employee',
    name: 'Amina',
    role: 'employee',
    active: true,
  );
  @override
  Stream<AuthSessionEvent> get changes => events.stream;
  @override
  Future<Result<Employee?>> restore() async => const Result.success(employee);
  @override
  Future<Result<Employee?>> login(String email, String password) async =>
      const Result.success(employee);
  @override
  Future<Result<void>> logout() async => const Result.success(null);
  @override
  Future<Result<void>> reset(String email) async => const Result.success(null);
  @override
  Future<Result<void>> password(String password) async =>
      const Result.success(null);
}

void expectEqual(Object? actual, Object? expected) {
  if (actual != expected) throw StateError('Expected $expected, got $actual');
}

Map<String, Future<void> Function()> scenarios = {
  'Schedule excludes holidays, weekends and dates before joining': () async {
    final m = WorkMonth(
      const [],
      {'2026-10-26'},
      [0, 1, 2, 3, 4],
      DateTime(2026, 10, 28),
      joinedAt: DateTime(2026, 10, 25),
    );
    expectEqual(m.scheduled(DateTime(2026, 10, 22)), false);
    expectEqual(m.scheduled(DateTime(2026, 10, 30)), false);
    expectEqual(m.scheduled(DateTime(2026, 10, 26)), false);
    expectEqual(m.scheduled(DateTime(2026, 10, 27)), true);
  },
  'Checkout duration uses recorded time rather than current clock': () async {
    final a = Attendance(
      day: DateTime(2026, 10, 28),
      checkIn: DateTime.utc(2026, 10, 28, 3),
      checkOut: DateTime.utc(2026, 10, 28, 12),
      status: 'present',
    );
    expectEqual(a.hours(DateTime.utc(2026, 10, 29)).inHours, 9);
  },
  'Latest history request wins when responses arrive out of order': () async {
    final repository = FakeAttendance();
    final cubit = HistoryCubit(AttendanceActions(repository));
    final first = cubit.load(DateTime(2026, 9));
    final second = cubit.load(DateTime(2026, 10));
    final september = WorkMonth(const [], {}, const [], DateTime(2026, 9, 1));
    final october = WorkMonth(const [], {}, const [], DateTime(2026, 10, 1));
    repository.requests[1].complete(Result.success(october));
    await second;
    repository.requests[0].complete(Result.success(september));
    await first;
    expectEqual(cubit.state.month, october);
    await cubit.close();
  },
  'Repeated check-in taps submit once and preserve friendly WiFi error':
      () async {
        final repository = FakeAttendance();
        final cubit = HomeCubit(AttendanceActions(repository));
        final first = cubit.punch('check_in');
        await cubit.punch('check_in');
        expectEqual(repository.punches, 1);
        repository.punchRequest.complete(
          const Result.failure(Failure('Connect to office WiFi')),
        );
        await first;
        expectEqual(cubit.state.status, LoadStatus.failure);
        expectEqual(cubit.state.message, 'Connect to office WiFi');
        expectEqual(cubit.state.busy, false);
        await cubit.close();
      },
  'Password recovery survives session restore until completion': () async {
    final repository = FakeAuth();
    final cubit = AuthCubit(AuthActions(repository));
    await cubit.restore();
    repository.events.add(AuthSessionEvent.passwordRecovery);
    await Future<void>.delayed(Duration.zero);
    expectEqual(cubit.state.recovering, true);
    expectEqual(cubit.state.employee, FakeAuth.employee);
    cubit.completeRecovery();
    expectEqual(cubit.state.recovering, false);
    await cubit.logout();
    expectEqual(cubit.state.employee, null);
    await cubit.close();
    await repository.events.close();
  },
};
