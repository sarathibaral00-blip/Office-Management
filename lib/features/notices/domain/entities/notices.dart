import 'package:equatable/equatable.dart';
import '../../../../core/domain/page_result.dart';

class Notice extends Equatable {
  const Notice(
    this.id,
    this.title,
    this.body,
    this.date,
    this.department,
    this.unread,
  );
  final String id, title, body;
  final DateTime date;
  final String? department;
  final bool unread;
  @override
  List<Object?> get props => [id, title, body, date, department, unread];
}

class NoticeData extends Equatable {
  const NoticeData(this.notices, this.departments);
  final List<Notice> notices;
  final List<Choice> departments;
  int get unread => notices.where((n) => n.unread).length;
  @override
  List<Object?> get props => [notices, departments];
}
