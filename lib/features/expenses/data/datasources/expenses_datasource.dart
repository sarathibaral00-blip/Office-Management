import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/expenses.dart';
import '../models/expense_model.dart';
import '../../../../core/export/private_file.dart';

class ExpensesDataSource {
  ExpensesDataSource(this.client);
  final SupabaseClient client;

  Future<ExpenseData> load() async {
    final out = <Expense>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('expense_claims')
          .select('*,profiles!expense_claims_employee_id_fkey(full_name)')
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      out.addAll(
        rows.map((j) => ExpenseModel.fromJson(j, client.auth.currentUser!.id)),
      );
      if (rows.length < 200) break;
    }
    return ExpenseData(out);
  }

  Future<String?> upload() => PrivateFileStore(
    client,
  ).upload('expense-receipts', client.auth.currentUser!.id);
  Future<void> submit(
    String title,
    String category,
    double amount,
    DateTime day,
    String receipt,
  ) async {
    await client.rpc(
      'submit_expense',
      params: {
        'p_title': title,
        'p_category': category,
        'p_amount': amount,
        'p_day': day.toIso8601String().split('T').first,
        'p_receipt': receipt,
      },
    );
  }

  Future<void> review(String id, String action, String comment) async {
    await client.rpc(
      'review_expense',
      params: {'p_id': id, 'p_action': action, 'p_comment': comment},
    );
  }

  Future<void> receipt(String path) =>
      PrivateFileStore(client).download('expense-receipts', path, 'receipt');
}
