import 'package:equatable/equatable.dart';
import '../../../../core/domain/page_result.dart';

class EmployeeDocument extends Equatable {
  const EmployeeDocument(
    this.id,
    this.employee,
    this.name,
    this.kind,
    this.title,
    this.path,
    this.date,
  );
  final String id, employee, name, kind, title, path;
  final DateTime date;
  @override
  List<Object?> get props => [id, employee, name, kind, title, path, date];
}

class DocumentData extends Equatable {
  const DocumentData(this.documents, this.employees, this.self);
  final List<EmployeeDocument> documents;
  final List<Choice> employees;
  final String self;
  @override
  List<Object?> get props => [documents, employees, self];
}
