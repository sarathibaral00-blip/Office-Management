import 'package:equatable/equatable.dart';

class Failure extends Equatable {
  const Failure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class Result<T> {
  const Result.success(this.value) : failure = null;
  const Result.failure(this.failure) : value = null;
  final T? value;
  final Failure? failure;
}

enum LoadStatus { initial, loading, success, failure }
