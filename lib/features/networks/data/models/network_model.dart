import '../../domain/entities/network.dart';

class NetworkModel extends OfficeNetwork {
  NetworkModel.fromJson(Map<String, dynamic> j)
    : super(
        id: j['id'] as String,
        label: j['label'] as String,
        network: j['network'] as String,
        branchId: j['branch_id'] as String,
        active: j['is_active'] as bool,
      );
}
