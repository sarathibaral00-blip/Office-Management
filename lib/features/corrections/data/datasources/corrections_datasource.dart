import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/corrections.dart';
import '../../../../core/domain/page_result.dart';
import '../models/correction_model.dart';

class CorrectionsDataSource {
  CorrectionsDataSource(this.client);
  final SupabaseClient client;

  Future<CorrectionData> load(int year) async {
    final out = <Correction>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('attendance_correction_requests')
          .select(
            '*,profiles!attendance_correction_requests_employee_id_fkey(full_name)',
          )
          .gte('created_at', '$year-01-01')
          .lt('created_at', '${year + 1}-01-01')
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      out.addAll(
        rows.map(
          (j) => CorrectionModel.fromJson(j, client.auth.currentUser!.id),
        ),
      );
      if (rows.length < 200) break;
    }
    final own = <Choice>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('attendance')
          .select('id,work_date,check_in,check_out')
          .eq('employee_id', client.auth.currentUser!.id)
          .gte('work_date', '$year-01-01')
          .lte('work_date', '$year-12-31')
          .order('work_date', ascending: false)
          .range(offset, offset + 199);
      own.addAll(
        rows.map(
          (j) => Choice(
            j['id'] as String,
            '${j['work_date']} · ${j['check_out'] == null ? 'Open' : 'Completed'}',
          ),
        ),
      );
      if (rows.length < 200) break;
    }
    return CorrectionData(out, own);
  }

  Future<void> request(
    String attendance,
    DateTime checkIn,
    DateTime? checkOut,
    String reason,
  ) async {
    await client.rpc(
      'request_attendance_correction',
      params: {
        'p_attendance': attendance,
        'p_in': checkIn.toUtc().toIso8601String(),
        'p_out': checkOut?.toUtc().toIso8601String(),
        'p_reason': reason,
      },
    );
  }

  Future<void> review(String id, bool approve, String comment) async {
    await client.rpc(
      'review_attendance_correction',
      params: {'p_id': id, 'p_approve': approve, 'p_comment': comment},
    );
  }
}
