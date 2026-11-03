import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  const Expense(
    this.id,
    this.name,
    this.mine,
    this.title,
    this.amount,
    this.day,
    this.receipt,
    this.status,
    this.comment,
  );
  final String id, name, title, receipt, status;
  final String? comment;
  final bool mine;
  final double amount;
  final DateTime day;
  @override
  List<Object?> get props => [
    id,
    name,
    mine,
    title,
    amount,
    day,
    receipt,
    status,
    comment,
  ];
}

class ExpenseData extends Equatable {
  const ExpenseData(this.claims);
  final List<Expense> claims;
  @override
  List<Object?> get props => [claims];
}
