import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/attendance_reports.dart';
import '../../../../core/domain/page_result.dart';
import '../models/attendance_report_model.dart';

class AttendanceReportsDataSource {
  AttendanceReportsDataSource(this.client);
  final SupabaseClient client;

  Future<List<Choice>> choices(String table) async {
    final out = <Choice>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from(table)
          .select('id,name')
          .order('id')
          .range(offset, offset + 199);
      out.addAll(
        rows.map((j) => Choice(j['id'] as String, j['name'] as String)),
      );
      if (rows.length < 200) return out;
    }
  }

  Future<AttendanceReportData> load(
    DateTime start,
    DateTime end,
    String? department,
    String? branch,
    int offset,
  ) async {
    final j = Map<String, dynamic>.from(
      await client.rpc(
            'attendance_report',
            params: {
              'p_start': start.toIso8601String().split('T').first,
              'p_end': end.toIso8601String().split('T').first,
              'p_department': department,
              'p_branch': branch,
              'p_offset': offset,
            },
          )
          as Map,
    );
    return AttendanceReportData(
      PageResult(
        (j['rows'] as List)
            .map(
              (r) => AttendanceReportModel.fromJson(
                Map<String, dynamic>.from(r as Map),
              ),
            )
            .toList(),
        j['has_more'] as bool,
      ),
      await choices('departments'),
      await choices('branches'),
      (j['total'] as num).toInt(),
      (j['present'] as num).toInt(),
      (j['late'] as num).toInt(),
      (j['absent'] as num).toDouble(),
      (j['hours'] as num).toDouble(),
    );
  }
}
