import '../../domain/entities/expenses.dart';

class ExpenseModel extends Expense {
  ExpenseModel.fromJson(Map<String, dynamic> j, String who)
    : super(
        j['id'] as String,
        (j['profiles'] as Map?)?['full_name'] as String? ?? 'Employee',
        j['employee_id'] == who,
        j['title'] as String,
        (j['amount'] as num).toDouble(),
        DateTime.parse(j['spent_on'] as String),
        j['receipt_path'] as String,
        j['status'] as String,
        j['review_comment'] as String?,
      );
}
