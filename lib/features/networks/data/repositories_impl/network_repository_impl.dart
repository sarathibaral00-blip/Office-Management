import '../../../../core/error/guard.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/network.dart';
import '../../domain/repositories/network_repository.dart';
import '../datasources/network_datasource.dart';

class NetworkRepositoryImpl implements NetworkRepository {
  NetworkRepositoryImpl(this.source);
  final NetworkDataSource source;
  @override
  Future<Result<NetworkList>> list() => guard(source.list);
  @override
  Future<Result<void>> save({
    String? id,
    required String label,
    required String network,
    required String branchId,
    required bool active,
  }) => guard(
    () => source.save(
      id: id,
      label: label,
      network: network,
      branchId: branchId,
      active: active,
    ),
  );
  @override
  Future<Result<void>> delete(String id) => guard(() => source.delete(id));
  @override
  Future<Result<String>> currentIp() => guard(source.currentIp);
  @override
  Future<Result<Branch>> createBranch(String name) =>
      guard(() => source.createBranch(name));
}
