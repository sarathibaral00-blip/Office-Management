import 'package:equatable/equatable.dart';
import '../../../../core/domain/page_result.dart';

class Letter extends Equatable {
  const Letter(this.id, this.name, this.kind, this.date);
  final String id, name, kind;
  final DateTime date;
  @override
  List<Object?> get props => [id, name, kind, date];
}

class LetterData extends Equatable {
  const LetterData(this.letters, this.employees);
  final List<Letter> letters;
  final List<Choice> employees;
  @override
  List<Object?> get props => [letters, employees];
}
