import '../../domain/entities/documents.dart';

class DocumentModel extends EmployeeDocument {
  DocumentModel.fromJson(Map<String, dynamic> j)
    : super(
        j['id'] as String,
        j['employee_id'] as String,
        (j['profiles'] as Map?)?['full_name'] as String? ?? 'Employee',
        j['kind'] as String,
        j['title'] as String,
        j['storage_path'] as String,
        DateTime.parse(j['created_at'] as String),
      );
}
