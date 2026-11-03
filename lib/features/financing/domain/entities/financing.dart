import 'package:equatable/equatable.dart';

class Financing extends Equatable {
  const Financing(
    this.id,
    this.name,
    this.mine,
    this.kind,
    this.amount,
    this.installment,
    this.start,
    this.status,
    this.reason,
    this.repaid,
  );
  final String id, name, kind, status, reason;
  final bool mine;
  final double amount, installment, repaid;
  final DateTime start;
  @override
  List<Object?> get props => [
    id,
    name,
    mine,
    kind,
    amount,
    installment,
    start,
    status,
    reason,
    repaid,
  ];
}

class FinancingData extends Equatable {
  const FinancingData(this.entries);
  final List<Financing> entries;
  @override
  List<Object?> get props => [entries];
}
