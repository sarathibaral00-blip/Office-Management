import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/notices.dart';
import '../../../../core/domain/page_result.dart';
import '../models/notice_model.dart';

class NoticesDataSource {
  NoticesDataSource(this.client);
  final SupabaseClient client;

  Future<NoticeData> load() async {
    final receipts = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('announcement_reads')
          .select()
          .eq('employee_id', client.auth.currentUser!.id)
          .order('announcement_id')
          .range(offset, offset + 199);
      receipts.addAll(rows);
      if (rows.length < 200) break;
    }
    final out = <Notice>[];
    for (var offset = 0; ; offset += 100) {
      final rows = await client
          .from('announcements')
          .select()
          .eq('is_active', true)
          .lte('published_at', DateTime.now().toUtc().toIso8601String())
          .order('published_at', ascending: false)
          .order('id')
          .range(offset, offset + 99);
      out.addAll(rows.map((j) => NoticeModel.fromJson(j, receipts)));
      if (rows.length < 100) break;
    }
    final deps = await client
        .from('departments')
        .select('id,name')
        .order('name');
    return NoticeData(
      out,
      deps.map((j) => Choice(j['id'] as String, j['name'] as String)).toList(),
    );
  }

  Future<void> save(
    String? id,
    String title,
    String body,
    String? department,
    bool active,
  ) async {
    await client.rpc(
      'save_announcement',
      params: {
        'p_id': id,
        'p_title': title,
        'p_body': body,
        'p_department': department,
        'p_active': active,
      },
    );
  }

  Future<void> read(String id) async {
    await client.rpc('mark_announcement_read', params: {'p_id': id});
  }
}
