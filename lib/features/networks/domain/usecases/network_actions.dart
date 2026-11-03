import '../repositories/network_repository.dart';
import '../../../../core/error/result.dart';
import '../entities/network.dart';

class NetworkActions {
  NetworkActions(this.repository);
  final NetworkRepository repository;
  Future<Result<NetworkList>> list() => repository.list();
  Future<Result<void>> save({
    String? id,
    required String label,
    required String network,
    required String branchId,
    required bool active,
  }) => repository.save(
    id: id,
    label: label,
    network: network,
    branchId: branchId,
    active: active,
  );
  Future<Result<void>> delete(String id) => repository.delete(id);
  Future<Result<String>> currentIp() => repository.currentIp();
  Future<Result<Branch>> createBranch(String name) =>
      repository.createBranch(name);
}
