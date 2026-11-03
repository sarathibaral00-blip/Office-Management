import 'package:equatable/equatable.dart';
import '../error/result.dart';

class FlowState<T> extends Equatable {
  const FlowState({
    this.status = LoadStatus.initial,
    this.data,
    this.message,
    this.busy = false,
  });
  final LoadStatus status;
  final T? data;
  final String? message;
  final bool busy;
  @override
  List<Object?> get props => [status, data, message, busy];
}
