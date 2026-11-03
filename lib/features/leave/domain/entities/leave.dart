import 'package:equatable/equatable.dart';

class LeaveBalance extends Equatable {
  const LeaveBalance(
    this.type,
    this.name,
    this.allocated,
    this.used,
    this.paid,
  );
  final String type, name;
  final double allocated, used;
  final bool paid;
  double get remaining => allocated - used;
  @override
  List<Object?> get props => [type, name, allocated, used, paid];
}

class LeaveEntry extends Equatable {
  const LeaveEntry({
    required this.id,
    required this.employee,
    required this.name,
    required this.type,
    required this.start,
    required this.end,
    required this.status,
    required this.reason,
    required this.mine,
    required this.half,
    this.period,
    this.comment,
    required this.days,
  });
  final String id, employee, name, type, status, reason;
  final DateTime start, end;
  final bool mine, half;
  final String? period, comment;
  final double days;
  @override
  List<Object?> get props => [
    id,
    employee,
    name,
    type,
    start,
    end,
    status,
    reason,
    mine,
    half,
    period,
    comment,
    days,
  ];
}

class LeaveData extends Equatable {
  const LeaveData(this.balances, this.entries);
  final List<LeaveBalance> balances;
  final List<LeaveEntry> entries;
  @override
  List<Object?> get props => [balances, entries];
}
