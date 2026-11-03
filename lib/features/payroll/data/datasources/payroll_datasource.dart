import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/payroll.dart';
import '../../../../core/domain/page_result.dart';
import 'dart:typed_data';
import '../models/payslip_model.dart';
import '../../../../core/export/export_service.dart';
import '../../../../core/export/report_data.dart';

class PayrollDataSource {
  PayrollDataSource(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> rows(String table, String fields) async {
    final out = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      final result = await client
          .from(table)
          .select(fields)
          .order('id')
          .range(offset, offset + 199);
      out.addAll(result);
      if (result.length < 200) return out;
    }
  }

  Future<PayrollData> load(int year) async {
    final slips = <Payslip>[];
    for (var offset = 0; ; offset += 100) {
      final result = await client
          .from('payroll')
          .select('*,profiles!payroll_employee_id_fkey(full_name)')
          .gte('month', '$year-01-01')
          .lte('month', '$year-12-31')
          .order('month', ascending: false)
          .order('id')
          .range(offset, offset + 99);
      slips.addAll(result.map(PayslipModel.fromJson));
      if (result.length < 100) break;
    }
    final runs = await rows('payroll_runs', 'id,month,status');
    final people = await rows('profiles', 'id,full_name,employee_code');
    final structures = <String, Map<String, Object?>>{};
    for (var offset = 0; ; offset += 200) {
      final result = await client
          .from('salary_structures')
          .select()
          .order('employee_id')
          .range(offset, offset + 199);
      for (final s in result) {
        structures[s['employee_id'] as String] = Map<String, Object?>.from(s);
      }
      if (result.length < 200) break;
    }
    return PayrollData(
      slips,
      runs
          .where((r) => DateTime.parse(r['month'] as String).year == year)
          .map(
            (r) => PayRun(
              r['id'] as String,
              DateTime.parse(r['month'] as String),
              r['status'] as String,
            ),
          )
          .toList(),
      people
          .map(
            (p) => Choice(
              p['id'] as String,
              '${p['employee_code']} · ${p['full_name']}',
            ),
          )
          .toList(),
      structures,
    );
  }

  Future<void> generate(DateTime month) async {
    await client.rpc(
      'generate_payroll',
      params: {
        'p_month': DateTime(
          month.year,
          month.month,
        ).toIso8601String().split('T').first,
      },
    );
  }

  Future<void> transition(String run, String action) async {
    await client.rpc(
      'transition_payroll',
      params: {'p_run': run, 'p_action': action},
    );
  }

  Future<void> salary(String employee, Map<String, Object?> values) async {
    await client.rpc(
      'save_salary_structure',
      params: {'p_employee': employee, 'p_data': values},
    );
  }

  Future<void> adjust(
    String id,
    double bonus,
    double extra,
    String reason,
  ) async {
    await client.rpc(
      'adjust_payroll',
      params: {
        'p_id': id,
        'p_bonus': bonus,
        'p_extra': extra,
        'p_reason': reason,
      },
    );
  }

  Future<void> payslip(String id, bool share) async {
    final j = await client
        .from('payroll')
        .select('*,profiles!payroll_employee_id_fkey(full_name)')
        .eq('id', id)
        .single();
    final p = PayslipModel.fromJson(j);
    if (!p.locked && j['run_id'] != null) {
      throw const FormatException('Lock payroll before exporting a payslip.');
    }
    Uint8List? logo;
    if (p.logoPath != null) {
      logo = await client.storage.from('company-assets').download(p.logoPath!);
    }
    await ExportService().report(
      ReportData(
        title:
            'Payslip · ${p.month.year}-${p.month.month.toString().padLeft(2, '0')}',
        subtitle: '${p.company}\n${p.companyAddress}',
        paragraphs: ['Employee: ${p.name}', 'Currency: ${p.currency}'],
        headers: const ['Component', 'Amount'],
        rows: [
          ...p.lines,
          ['Net pay', p.net.toStringAsFixed(2)],
        ],
        logo: logo,
      ),
      'payslip-${p.month.year}-${p.month.month}-${p.employee}',
      'pdf',
      share: share,
    );
  }

  Future<void> bank(String run) async {
    final r = await client.from('payroll_runs').select().eq('id', run).single();
    if (r['status'] != 'locked') {
      throw const FormatException(
        'Lock the payroll run before exporting its bank sheet.',
      );
    }
    final all = <List<Object?>>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('payroll')
          .select('net,employee_snapshot')
          .eq('run_id', run)
          .order('id')
          .range(offset, offset + 199);
      for (final p in rows) {
        if ((p['net'] as num) <= 0) continue;
        final s = p['employee_snapshot'] as Map;
        if ((s['account_number'] as String? ?? '').isEmpty) {
          throw const FormatException(
            'A payslip is missing its bank snapshot. Record the payment through a reviewed bank process.',
          );
        }
        all.add([
          s['code'],
          s['name'],
          s['bank_name'],
          s['account_name'],
          s['account_number'],
          p['net'],
        ]);
      }
      if (rows.length < 200) break;
    }
    await ExportService().report(
      ReportData(
        title: 'Bank sheet',
        headers: const [
          'Employee ID',
          'Employee',
          'Bank',
          'Account name',
          'Account number',
          'Net pay',
        ],
        rows: all,
      ),
      'bank-${r['month']}',
      'csv',
    );
  }
}
