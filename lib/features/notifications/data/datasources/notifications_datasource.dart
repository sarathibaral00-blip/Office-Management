import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/notifications.dart';
import '../models/inbox_model.dart';

class NotificationsDataSource {
  NotificationsDataSource(this.client);
  final SupabaseClient client;

  Future<InboxData> load() async {
    final out = <InboxItem>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      out.addAll(rows.map(InboxModel.fromJson));
      if (rows.length < 200) break;
    }
    return InboxData(out);
  }

  Future<void> read(String? id) async {
    await client.rpc('read_notifications', params: {'p_id': id});
  }
}
