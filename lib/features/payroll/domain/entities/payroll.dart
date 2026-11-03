import 'package:equatable/equatable.dart';
import '../../../../core/domain/page_result.dart';

class Payslip extends Equatable {
  const Payslip({
    required this.id,
    required this.employee,
    required this.name,
    required this.month,
    required this.basic,
    required this.allowances,
    required this.deductions,
    required this.net,
    required this.source,
    required this.locked,
    required this.bonus,
    required this.extra,
    required this.lines,
    required this.company,
    required this.companyAddress,
    required this.currency,
    this.logoPath,
    this.run,
  });
  final String id, employee, name, source, company, companyAddress, currency;
  final String? logoPath, run;
  final DateTime month;
  final double basic, allowances, deductions, net, bonus, extra;
  final bool locked;
  final List<List<Object?>> lines;
  @override
  List<Object?> get props => [
    id,
    employee,
    name,
    month,
    basic,
    allowances,
    deductions,
    net,
    source,
    locked,
    bonus,
    extra,
    lines,
    company,
    companyAddress,
    currency,
    logoPath,
    run,
  ];
}

class PayRun extends Equatable {
  const PayRun(this.id, this.month, this.status);
  final String id, status;
  final DateTime month;
  @override
  List<Object?> get props => [id, month, status];
}

class PayrollData extends Equatable {
  const PayrollData(this.slips, this.runs, this.employees, this.structures);
  final List<Payslip> slips;
  final List<PayRun> runs;
  final List<Choice> employees;
  final Map<String, Map<String, Object?>> structures;
  double get total => slips.fold(0, (n, p) => n + p.net);
  @override
  List<Object?> get props => [slips, runs, employees, structures];
}
