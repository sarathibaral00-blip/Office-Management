import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_actions.dart';

class AuthState extends Equatable {
  const AuthState({
    this.status = LoadStatus.initial,
    this.employee,
    this.message,
    this.recovering = false,
  });
  final bool recovering;
  final LoadStatus status;
  final Employee? employee;
  final String? message;
  @override
  List<Object?> get props => [status, employee, message, recovering];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this.actions) : super(const AuthState()) {
    subscription = actions.changes.listen((event) {
      if (event == AuthSessionEvent.passwordRecovery) {
        emit(
          AuthState(
            status: state.status,
            employee: state.employee,
            recovering: true,
          ),
        );
      }
      restore();
    });
  }
  final AuthActions actions;
  int revision = 0;
  StreamSubscription<AuthSessionEvent>? subscription;
  Future<void> restore() async {
    final request = ++revision;
    final r = await actions.restore();
    if (!isClosed && request == revision) {
      emit(
        AuthState(
          status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
          employee: r.value,
          recovering: state.recovering,
          message: r.failure?.message,
        ),
      );
    }
  }

  Future<void> login(String e, String p) async {
    final request = ++revision;
    emit(const AuthState(status: LoadStatus.loading));
    final r = await actions.login(e, p);
    if (!isClosed && request == revision) {
      emit(
        AuthState(
          status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
          employee: r.value,
          recovering: state.recovering,
          message: r.failure?.message,
        ),
      );
    }
  }

  Future<void> logout() async {
    final request = ++revision;
    final r = await actions.logout();
    if (!isClosed && request == revision) {
      emit(
        AuthState(
          status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
          employee: r.failure == null ? null : state.employee,
          message: r.failure?.message,
        ),
      );
    }
  }

  void completeRecovery() {
    emit(AuthState(status: state.status, employee: state.employee));
  }

  @override
  Future<void> close() async {
    await subscription?.cancel();
    return super.close();
  }
}

class PasswordState extends Equatable {
  const PasswordState([this.status = LoadStatus.initial, this.message]);
  final LoadStatus status;
  final String? message;
  @override
  List<Object?> get props => [status, message];
}

class PasswordCubit extends Cubit<PasswordState> {
  PasswordCubit(this.actions) : super(const PasswordState());
  final AuthActions actions;
  Future<void> submit(String value, {bool update = false}) async {
    emit(const PasswordState(LoadStatus.loading));
    final r = await (update ? actions.password(value) : actions.reset(value));
    if (isClosed) return;
    emit(
      PasswordState(
        r.failure == null ? LoadStatus.success : LoadStatus.failure,
        r.failure?.message ??
            (update
                ? 'Password updated. You can return to your workspace.'
                : 'Check your email for a password reset link.'),
      ),
    );
  }
}
