import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/letters.dart';
import '../../../../core/domain/page_result.dart';
import '../models/letter_model.dart';
import '../models/letter_templates.dart';
import '../../../../core/export/export_service.dart';
import '../../../../core/export/report_data.dart';

class LettersDataSource {
  LettersDataSource(this.client);
  final SupabaseClient client;

  Future<LetterData> load() async {
    final letters = <Letter>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('generated_letters')
          .select()
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      letters.addAll(rows.map((j) => LetterModel.fromJson(j)));
      if (rows.length < 200) break;
    }
    final people = <Choice>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('profiles')
          .select('id,full_name,employee_code')
          .order('id')
          .range(offset, offset + 199);
      people.addAll(
        rows.map(
          (j) => Choice(
            j['id'] as String,
            '${j['employee_code']} · ${j['full_name']}',
          ),
        ),
      );
      if (rows.length < 200) break;
    }
    return LetterData(letters, people);
  }

  Future<void> issue(String employee, String kind, String purpose) async {
    final id =
        await client.rpc(
              'issue_letter',
              params: {
                'p_employee': employee,
                'p_kind': kind,
                'p_purpose': purpose,
              },
            )
            as String;
    await export(id, false);
  }

  Future<void> export(String id, bool share) async {
    final j = await client
        .from('generated_letters')
        .select()
        .eq('id', id)
        .single();
    final s = j['snapshot'] as Map;
    final e = s['employee'] as Map;
    final c = s['company'] as Map;
    final logo = await client.storage
        .from('company-assets')
        .download(c['logo_path'] as String);
    final signature = await client.storage
        .from('company-assets')
        .download(c['signature_path'] as String);
    await ExportService().report(
      ReportData(
        title: letterTitle(j['kind'] as String),
        subtitle: '${c['name']} | ${c['address']}',
        paragraphs: [
          'Reference: ${j['id']}',
          'Date: ${(j['created_at'] as String).split('T').first}',
          'Employee: ${e['name']} (${e['code']})',
          letterBody(j['kind'] as String, e, c),
          'Purpose / terms: ${j['purpose']}',
          'Issued by ${c['name']}.',
        ],
        logo: logo,
        signature: signature,
      ),
      '${j['kind']}-${e['code']}-${j['id']}',
      'pdf',
      share: share,
    );
  }
}
