import 'package:equatable/equatable.dart';
import '../../../../core/domain/page_result.dart';

class ExportOptions extends Equatable {
  const ExportOptions(this.departments, this.branches);
  final List<Choice> departments, branches;
  @override
  List<Object?> get props => [departments, branches];
}
