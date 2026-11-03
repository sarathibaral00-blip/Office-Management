import 'package:equatable/equatable.dart';

class OfficeNetwork extends Equatable {
  const OfficeNetwork({
    required this.id,
    required this.label,
    required this.network,
    required this.branchId,
    required this.active,
  });
  final String id, label, network, branchId;
  final bool active;
  @override
  List<Object?> get props => [id, label, network, branchId, active];
}

class Branch extends Equatable {
  const Branch(this.id, this.name);
  final String id, name;
  @override
  List<Object?> get props => [id, name];
}

class NetworkList {
  const NetworkList(this.networks, this.branches);
  final List<OfficeNetwork> networks;
  final List<Branch> branches;
}
