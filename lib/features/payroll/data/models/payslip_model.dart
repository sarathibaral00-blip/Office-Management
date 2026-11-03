import '../../domain/entities/payroll.dart';

class PayslipModel extends Payslip {
  PayslipModel.fromJson(Map<String, dynamic> j)
    : super(
        id: j['id'] as String,
        employee: j['employee_id'] as String,
        name:
            (j['employee_snapshot'] as Map?)?['name'] as String? ??
            (j['profiles'] as Map?)?['full_name'] as String? ??
            'Employee',
        month: DateTime.parse(j['month'] as String),
        basic: (j['basic'] as num).toDouble(),
        allowances: (j['allowances'] as num).toDouble(),
        deductions: (j['deductions'] as num).toDouble(),
        net: (j['net'] as num).toDouble(),
        source: j['status'] as String,
        locked:
            j['locked_at'] != null ||
            (j['run_id'] == null && ['approved', 'paid'].contains(j['status'])),
        bonus: (j['bonus'] as num? ?? 0).toDouble(),
        extra: (j['extra_deduction'] as num? ?? 0).toDouble(),
        lines: buildLines(j),
        company:
            ((j['employee_snapshot'] as Map?)?['company'] as Map?)?['name']
                as String? ??
            'Pride People',
        companyAddress:
            ((j['employee_snapshot'] as Map?)?['company'] as Map?)?['address']
                as String? ??
            '',
        currency:
            ((j['employee_snapshot'] as Map?)?['company'] as Map?)?['currency']
                as String? ??
            'BDT',
        logoPath:
            ((j['employee_snapshot'] as Map?)?['company'] as Map?)?['logo_path']
                as String?,
        run: j['run_id'] as String?,
      );
  static List<List<Object?>> buildLines(Map<String, dynamic> j) => [
    for (final e in const {
      'basic': 'Basic',
      'house_rent': 'House rent',
      'medical': 'Medical',
      'conveyance': 'Conveyance',
      'bonus': 'Bonus',
      'overtime_pay': 'Overtime',
      'absence_deduction': 'Absent deduction',
      'late_deduction': 'Late deduction',
      'installment_deduction': 'Loan / advance',
      'extra_deduction': 'Other deduction',
    }.entries)
      [e.value, (j[e.key] as num? ?? 0).toStringAsFixed(2)],
    ['Total allowances', (j['allowances'] as num).toStringAsFixed(2)],
    ['Total deductions', (j['deductions'] as num).toStringAsFixed(2)],
  ];
}
