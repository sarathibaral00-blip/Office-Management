import 'dart:async';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/features/networks/domain/entities/network.dart';
import 'package:hr_management/features/networks/domain/repositories/network_repository.dart';
import 'package:hr_management/features/networks/domain/usecases/network_actions.dart';
import 'package:hr_management/features/networks/presentation/bloc/network_cubit.dart';

class _Networks implements NetworkRepository {
  final creation = Completer<Result<Branch>>();
  int creates = 0;
  String? submittedName;
  @override
  Future<Result<Branch>> createBranch(String name) {
    creates++;
    submittedName = name;
    return creation.future;
  }

  @override
  Future<Result<NetworkList>> list() async => const Result.success(
    NetworkList([
      OfficeNetwork(
        id: 'network',
        label: 'Office',
        network: '192.0.2.1',
        branchId: 'existing',
        active: true,
      ),
    ], []),
  );
  @override
  Future<Result<String>> currentIp() async => const Result.success('192.0.2.1');
  @override
  Future<Result<void>> delete(String id) => throw UnimplementedError();
  @override
  Future<Result<void>> save({
    String? id,
    required String label,
    required String network,
    required String branchId,
    required bool active,
  }) => throw UnimplementedError();
}

void _expect(bool value, String reason) {
  if (!value) throw StateError(reason);
}

final networkScenarios = <String, Future<void> Function()>{
  'Branch setup submits once and preserves loaded networks after creation':
      () async {
        final repo = _Networks();
        final cubit = NetworkCubit(NetworkActions(repo));
        await cubit.load();
        final first = cubit.createBranch('  Head Office  ');
        _expect(
          !await cubit.createBranch('Head Office'),
          'Duplicate submission accepted',
        );
        _expect(
          repo.creates == 1 && repo.submittedName == 'Head Office',
          'Wrong branch submission',
        );
        repo.creation.complete(
          const Result.success(Branch('branch', 'Head Office')),
        );
        _expect(await first, 'Successful creation failed');
        _expect(
          cubit.state.data!.branches.single.id == 'branch',
          'Created branch not selectable',
        );
        _expect(
          cubit.state.data!.networks.single.id == 'network' &&
              !cubit.state.busy,
          'Network list lost or busy stuck',
        );
        await cubit.close();
      },
  'Denied branch creation preserves data and surfaces the server failure':
      () async {
        final repo = _Networks();
        final cubit = NetworkCubit(NetworkActions(repo));
        await cubit.load();
        final result = cubit.createBranch('Head Office');
        repo.creation.complete(
          const Result.failure(Failure('Only HR can create a branch.')),
        );
        _expect(!await result, 'Rejected branch marked created');
        _expect(
          cubit.state.data!.branches.isEmpty &&
              cubit.state.data!.networks.length == 1,
          'Rejected creation changed records',
        );
        _expect(
          !cubit.state.busy &&
              cubit.state.message == 'Only HR can create a branch.',
          'Failure lost or busy stuck',
        );
        await cubit.close();
      },
  'Empty branch names are rejected before any repository call': () async {
    final repo = _Networks();
    final cubit = NetworkCubit(NetworkActions(repo));
    _expect(!await cubit.createBranch('   '), 'Empty name accepted');
    _expect(repo.creates == 0, 'Invalid name reached server');
    await cubit.close();
  },
};
