import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/documents.dart';
import '../../../../core/domain/page_result.dart';
import '../models/document_model.dart';
import '../../../../core/export/private_file.dart';

class DocumentsDataSource {
  DocumentsDataSource(this.client);
  final SupabaseClient client;

  Future<DocumentData> load() async {
    final docs = <EmployeeDocument>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('employee_documents')
          .select('*,profiles!employee_documents_employee_id_fkey(full_name)')
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      docs.addAll(rows.map(DocumentModel.fromJson));
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
    return DocumentData(docs, people, client.auth.currentUser!.id);
  }

  Future<void> upload(String employee, String kind, String title) async {
    final path = await PrivateFileStore(
      client,
    ).upload('employee-documents', employee);
    if (path == null) return;
    await client.rpc(
      'register_employee_document',
      params: {
        'p_employee': employee,
        'p_kind': kind,
        'p_title': title,
        'p_path': path,
      },
    );
  }

  Future<void> download(String path, String title) =>
      PrivateFileStore(client).download('employee-documents', path, title);
}
