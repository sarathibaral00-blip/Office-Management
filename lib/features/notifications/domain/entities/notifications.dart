import 'package:equatable/equatable.dart';

class InboxItem extends Equatable {
  const InboxItem(
    this.id,
    this.title,
    this.body,
    this.kind,
    this.date,
    this.read,
  );
  final String id, title, body, kind;
  final DateTime date;
  final bool read;
  @override
  List<Object?> get props => [id, title, body, kind, date, read];
}

class InboxData extends Equatable {
  const InboxData(this.items);
  final List<InboxItem> items;
  int get unread => items.where((n) => !n.read).length;
  @override
  List<Object?> get props => [items];
}
