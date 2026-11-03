import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/financing.dart';
import '../models/financing_model.dart';

class FinancingDataSource {
  FinancingDataSource(this.client);
  final SupabaseClient client;

  Future<FinancingData> load() async {
    final out = <Financing>[];
    final paid = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('payroll_installments')
          .select('financing_id,amount')
          .not('posted_at', 'is', null)
          .order('id')
          .range(offset, offset + 199);
      paid.addAll(rows);
      if (rows.length < 200) break;
    }
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('employee_financing')
          .select('*,profiles!employee_financing_employee_id_fkey(full_name)')
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      out.addAll(
        rows.map(
          (j) => FinancingModel.fromJson(j, client.auth.currentUser!.id, paid),
        ),
      );
      if (rows.length < 200) break;
    }
    return FinancingData(out);
  }

  Future<void> request(
    String kind,
    double amount,
    int count,
    DateTime month,
    String reason,
  ) async {
    await client.rpc(
      'request_financing',
      params: {
        'p_kind': kind,
        'p_amount': amount,
        'p_installments': count,
        'p_month': DateTime(
          month.year,
          month.month,
        ).toIso8601String().split('T').first,
        'p_reason': reason,
      },
    );
  }

  Future<void> review(String id, String action, String comment) async {
    await client.rpc(
      'review_financing',
      params: {'p_id': id, 'p_action': action, 'p_comment': comment},
    );
  }
}
