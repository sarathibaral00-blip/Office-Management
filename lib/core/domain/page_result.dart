import 'package:equatable/equatable.dart';

class PageResult<T> extends Equatable {
  const PageResult(this.items, this.hasMore);
  final List<T> items;
  final bool hasMore;
  @override
  List<Object?> get props => [items, hasMore];
}

class Choice extends Equatable {
  const Choice(this.id, this.label);
  final String id, label;
  @override
  List<Object?> get props => [id, label];
}
