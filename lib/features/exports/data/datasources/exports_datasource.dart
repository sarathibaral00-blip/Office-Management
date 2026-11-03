import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/exports.dart';
import '../../../../core/domain/page_result.dart';
import '../../../../core/export/export_service.dart';
import '../../../../core/export/report_data.dart';

class ExportsDataSource {
  ExportsDataSource(this.client);
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

  Future<ExportOptions> load() async =>
      ExportOptions(await choices('departments'), await choices('branches'));
  Future<void> export(
    String kind,
    DateTime start,
    DateTime end,
    String? department,
    String? branch,
    String format,
    bool share,
  ) async {
    final rows = <List<Object?>>[];
    List<String> headers = [];
    var from = DateTime(start.year, start.month, start.day);
    final finish = DateTime(end.year, end.month, end.day);
    if (finish.isBefore(from) || finish.difference(from).inDays > 366) {
      throw const FormatException('Choose a range of up to one year.');
    }
    while (!from.isAfter(finish)) {
      final monthEnd = DateTime(from.year, from.month + 1, 0);
      final to = kind == 'attendance' && monthEnd.isBefore(finish)
          ? monthEnd
          : finish;
      var offset = 0;
      while (true) {
        final j = Map<String, dynamic>.from(
          await client.rpc(
                'export_rows',
                params: {
                  'p_kind': kind,
                  'p_start': from.toIso8601String().split('T').first,
                  'p_end': to.toIso8601String().split('T').first,
                  'p_offset': offset,
                  'p_department': department,
                  'p_branch': branch,
                },
              )
              as Map,
        );
        headers = List<String>.from(j['headers'] as List);
        final chunk = (j['rows'] as List)
            .map((r) => List<Object?>.from(r as List))
            .toList();
        rows.addAll(chunk);
        if (j['has_more'] != true) break;
        if (chunk.isEmpty) {
          throw const FormatException(
            'Export changed while paging. Please retry.',
          );
        }
        offset += chunk.length;
      }
      from = DateTime(to.year, to.month, to.day + 1);
    }
    await ExportService().report(
      ReportData(
        title: '${kind[0].toUpperCase()}${kind.substring(1)} report',
        subtitle:
            '${start.toIso8601String().split('T').first} to ${end.toIso8601String().split('T').first}',
        paragraphs: ['${rows.length} rows'],
        headers: headers,
        rows: rows,
      ),
      '$kind-${start.year}-${start.month}-${start.day}',
      format,
      share: share,
    );
  }
}
