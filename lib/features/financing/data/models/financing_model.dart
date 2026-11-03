import '../../domain/entities/financing.dart';

class FinancingModel extends Financing {
  FinancingModel.fromJson(
    Map<String, dynamic> j,
    String who,
    List<Map<String, dynamic>> paid,
  ) : super(
        j['id'] as String,
        (j['profiles'] as Map?)?['full_name'] as String? ?? 'Employee',
        j['employee_id'] == who,
        j['kind'] as String,
        (j['amount'] as num).toDouble(),
        (j['installment_amount'] as num).toDouble(),
        DateTime.parse(j['starts_month'] as String),
        j['status'] as String,
        j['reason'] as String,
        paid
            .where((p) => p['financing_id'] == j['id'])
            .fold<double>(0, (n, p) => n + (p['amount'] as num).toDouble()),
      );
}
