import 'dart:async';
import 'dart:typed_data';
import 'package:hr_management/core/domain/page_result.dart';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/features/employees/domain/entities/employees.dart';
import 'package:hr_management/features/employees/domain/repositories/employees_repository.dart';
import 'package:hr_management/features/employees/domain/usecases/employees_actions.dart';
import 'package:hr_management/features/employees/presentation/bloc/employees_cubit.dart';
import 'package:hr_management/features/leave/domain/entities/leave.dart';
import 'package:hr_management/features/leave/domain/repositories/leave_repository.dart';
import 'package:hr_management/features/leave/domain/usecases/leave_actions.dart';
import 'package:hr_management/features/leave/presentation/bloc/leave_cubit.dart';
import 'package:hr_management/features/notices/data/models/notice_model.dart';
import 'package:hr_management/features/profile/data/models/photo_format.dart';
import 'package:hr_management/features/profile/domain/entities/profile.dart';
import 'package:hr_management/features/profile/domain/repositories/profile_repository.dart';
import 'package:hr_management/features/profile/domain/usecases/profile_actions.dart';
import 'package:hr_management/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:hr_management/features/attendance/domain/entities/attendance.dart';
import 'scenarios.dart' show expectEqual;

class FakeEmployees implements EmployeesRepository {
  final pending = <Completer<Result<Directory>>>[];
  static const staff = Staff(
    id: 'employee',
    name: 'Amina',
    code: 'EMP-1',
    email: 'amina@example.com',
    role: 'employee',
    salary: 100,
    active: true,
  );
  @override
  Future<Result<Directory>> list(
    String search,
    String? department,
    String? branch,
    bool? active,
    int offset,
  ) {
    final c = Completer<Result<Directory>>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<Result<Choice>> createDepartment(String name) async =>
      Result.success(Choice('department-new', name));
  @override
  Future<Result<Staff>> detail(String id) async => const Result.success(staff);
  @override
  Future<Result<void>> create(Map<String, Object?> data) async =>
      const Result.failure(Failure('Duplicate email'));
  @override
  Future<Result<void>> update(String id, Map<String, Object?> data) async =>
      const Result.failure(
        Failure('You cannot change your own role, salary or active status'),
      );
  @override
  Future<Result<void>> pin(String id, String pin) async =>
      const Result.success(null);
}

class FakeLeave implements LeaveRepository {
  static const initial = LeaveData([
    LeaveBalance('annual', 'Annual', 10, 2, true),
  ], []);
  int reviews = 0;
  final reviewResponse = Completer<Result<void>>();
  @override
  Future<Result<LeaveData>> load(int year) async =>
      const Result.success(initial);
  @override
  Future<Result<void>> apply(
    String type,
    DateTime start,
    DateTime end,
    bool half,
    String? period,
    String reason,
  ) async => const Result.success(null);
  @override
  Future<Result<void>> cancel(String id) async => const Result.failure(
    Failure('Only your pending requests can be cancelled'),
  );
  @override
  Future<Result<void>> review(String id, bool approve, String comment) {
    reviews++;
    return reviewResponse.future;
  }
}

class FakeProfile implements ProfileRepository {
  static const profile = MyProfile(
    'employee',
    'Amina',
    'EMP-1',
    'amina@example.com',
    null,
    null,
  );
  int passwords = 0;
  final response = Completer<Result<void>>();
  @override
  Future<Result<MyProfile>> load() async => const Result.success(profile);
  @override
  Future<Result<void>> phone(String phone) async => const Result.success(null);
  @override
  Future<Result<void>> photo() async => const Result.success(null);
  @override
  Future<Result<void>> password(String password) {
    passwords++;
    return response.future;
  }
}

final Map<String, Future<void> Function()> workflowScenarios = {
  'Directory ignores a stale search response': () async {
    final repo = FakeEmployees();
    final cubit = EmployeesCubit(EmployeesActions(repo));
    final first = cubit.load();
    cubit.search = 'Amina';
    final second = cubit.load();
    const latest = Directory(
      PageResult([FakeEmployees.staff], false),
      [],
      [],
      [],
      [],
    );
    repo.pending[1].complete(const Result.success(latest));
    await second;
    repo.pending[0].complete(
      const Result.success(Directory(PageResult([], false), [], [], [], [])),
    );
    await first;
    expectEqual(cubit.state.data, latest);
    await cubit.close();
  },
  'Employee edit failures surface protected-field errors and release busy state':
      () async {
        final cubit = EmployeeDetailCubit(EmployeesActions(FakeEmployees()));
        expectEqual(await cubit.save('employee', {'salary': 200}), false);
        expectEqual(cubit.state.message!.contains('own role'), true);
        expectEqual(cubit.state.busy, false);
        await cubit.close();
      },
  'Leave approval waits for the server and never deducts balances in the client':
      () async {
        final repo = FakeLeave();
        final cubit = LeaveCubit(LeaveActions(repo));
        await cubit.load();
        final first = cubit.review('request', true, 'Approved');
        expectEqual(cubit.state.data, FakeLeave.initial);
        expectEqual(await cubit.review('request', true, 'Approved'), false);
        expectEqual(repo.reviews, 1);
        repo.reviewResponse.complete(
          const Result.failure(Failure('Insufficient leave balance')),
        );
        await first;
        expectEqual(cubit.state.data!.balances.single.used, 2.0);
        expectEqual(cubit.state.message, 'Insufficient leave balance');
        expectEqual(cubit.state.busy, false);
        await cubit.close();
      },
  'Rejected leave cancellation preserves history and surfaces the server reason':
      () async {
        final cubit = LeaveCubit(LeaveActions(FakeLeave()));
        await cubit.load();
        expectEqual(await cubit.cancel('already-approved'), false);
        expectEqual(cubit.state.data, FakeLeave.initial);
        expectEqual(cubit.state.status, LoadStatus.failure);
        await cubit.close();
      },
  'A notice edited after reading becomes unread again': () async {
    final json = <String, dynamic>{
      'id': 'notice',
      'title': 'Update',
      'body': 'Message',
      'published_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-02T00:00:00Z',
    };
    expectEqual(NoticeModel.fromJson(json, []).unread, true);
    expectEqual(
      NoticeModel.fromJson(json, [
        {'announcement_id': 'notice', 'read_at': '2026-10-01T00:00:00Z'},
      ]).unread,
      true,
    );
    expectEqual(
      NoticeModel.fromJson(json, [
        {'announcement_id': 'notice', 'read_at': '2026-10-03T00:00:00Z'},
      ]).unread,
      false,
    );
    expectEqual(
      NoticeModel.fromJson(json, [
        {'announcement_id': 'another', 'read_at': '2026-10-03T00:00:00Z'},
      ]).unread,
      true,
    );
  },
  'Photo format checks reject unsupported and oversized uploads': () async {
    expectEqual(
      photoFormat(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]),
      )?.mime,
      'image/png',
    );
    expectEqual(
      photoFormat(
        Uint8List.fromList([255, 216, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      )?.extension,
      'jpg',
    );
    expectEqual(
      photoFormat(Uint8List.fromList('not an image payload'.codeUnits)),
      null,
    );
    expectEqual(photoFormat(Uint8List(5 * 1024 * 1024 + 1)), null);
  },
  'Password updates are submitted once and never retained in Cubit state':
      () async {
        final repo = FakeProfile();
        final cubit = ProfileCubit(ProfileActions(repo));
        await cubit.load();
        final first = cubit.password('new-secret-password');
        await cubit.password('new-secret-password');
        expectEqual(repo.passwords, 1);
        repo.response.complete(
          const Result.failure(Failure('Reauthentication required')),
        );
        await first;
        expectEqual(
          cubit.state.toString().contains('new-secret-password'),
          false,
        );
        expectEqual(cubit.state.data, FakeProfile.profile);
        expectEqual(cubit.state.busy, false);
        await cubit.close();
      },
  'Full approved leave excludes inferred absence while a half day remains scheduled':
      () async {
        final m = WorkMonth(
          const [],
          {},
          const [0, 1, 2, 3, 4, 5, 6],
          DateTime(2026, 10, 28),
          leaveUnits: const {'2026-10-20': 1, '2026-10-21': 0.5},
        );
        expectEqual(m.scheduled(DateTime(2026, 10, 20)), false);
        expectEqual(m.scheduled(DateTime(2026, 10, 21)), true);
      },
};
