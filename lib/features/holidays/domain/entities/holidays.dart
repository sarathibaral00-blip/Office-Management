import 'package:equatable/equatable.dart';
import '../../../../core/domain/page_result.dart';

class Holiday extends Equatable {
  const Holiday(this.id, this.name, this.day, this.branch);
  final String id, name;
  final DateTime day;
  final String? branch;
  @override
  List<Object?> get props => [id, name, day, branch];
}

class HolidayData extends Equatable {
  const HolidayData(this.holidays, this.branches);
  final List<Holiday> holidays;
  final List<Choice> branches;
  @override
  List<Object?> get props => [holidays, branches];
}
