import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/holidays.dart';
import '../../../../core/domain/page_result.dart';
import '../models/holiday_model.dart';

class HolidaysDataSource {
  HolidaysDataSource(this.client);
  final SupabaseClient client;

  Future<HolidayData> load(int year) async {
    final out = <Holiday>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('holidays')
          .select()
          .eq('is_active', true)
          .gte('holiday_date', '$year-01-01')
          .lte('holiday_date', '$year-12-31')
          .order('holiday_date')
          .order('id')
          .range(offset, offset + 199);
      out.addAll(rows.map(HolidayModel.fromJson));
      if (rows.length < 200) break;
    }
    final branches = await client
        .from('branches')
        .select('id,name')
        .order('name');
    return HolidayData(
      out,
      branches
          .map((j) => Choice(j['id'] as String, j['name'] as String))
          .toList(),
    );
  }

  Future<void> save(
    String? id,
    String name,
    DateTime day,
    String? branch,
    bool active,
  ) async {
    await client.rpc(
      'save_holiday',
      params: {
        'p_id': id,
        'p_name': name,
        'p_date': day.toIso8601String().split('T').first,
        'p_branch': branch,
        'p_active': active,
      },
    );
  }
}
