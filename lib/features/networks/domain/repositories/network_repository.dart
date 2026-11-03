import '../../../../core/error/result.dart';
import '../entities/network.dart';

abstract class NetworkRepository {
  Future<Result<NetworkList>> list();
  Future<Result<void>> save({
    String? id,
    required String label,
    required String network,
    required String branchId,
    required bool active,
  });
  Future<Result<void>> delete(String id);
  Future<Result<String>> currentIp();
  Future<Result<Branch>> createBranch(String name);
}
