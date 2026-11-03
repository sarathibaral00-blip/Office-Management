import 'package:equatable/equatable.dart';
import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/usecases/attendance_actions.dart';

class AttendanceState extends Equatable {
  const AttendanceState({
    this.status = LoadStatus.initial,
    this.month,
    this.message,
    this.allowed,
    this.busy = false,
  });
  final LoadStatus status;
  final WorkMonth? month;
  final String? message;
  final bool? allowed;
  final bool busy;
  @override
  List<Object?> get props => [status, month, message, allowed, busy];
}

class AttendanceCubit extends Cubit<AttendanceState> {
  AttendanceCubit(this.actions) : super(const AttendanceState());
  final AttendanceActions actions;
  DateTime selected = DateTime.now();
  bool get currentMonth => false;
  int generation = 0;
  bool punching = false;
  Future<void> load([DateTime? m]) async {
    selected = m ?? selected;
    final request = ++generation;
    emit(AttendanceState(status: LoadStatus.loading, month: state.month));
    final r = await actions.month(currentMonth ? null : selected);
    if (isClosed || request != generation) return;
    emit(
      AttendanceState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        month: r.value,
        message: r.failure?.message,
      ),
    );
  }

  Future<void> verify() async {
    final r = await actions.network();
    if (!isClosed) {
      emit(
        AttendanceState(
          status: state.status,
          month: state.month,
          allowed: r.value ?? false,
          message: r.failure?.message,
          busy: punching,
        ),
      );
    }
  }

  Future<void> punch(String a) async {
    if (punching) return;
    punching = true;
    emit(
      AttendanceState(
        status: state.status,
        month: state.month,
        allowed: state.allowed,
        busy: true,
      ),
    );
    final r = await actions.punch(a);
    punching = false;
    if (isClosed) return;
    if (r.failure != null) {
      emit(
        AttendanceState(
          status: LoadStatus.failure,
          month: state.month,
          message: r.failure!.message,
          allowed: r.failure!.message == 'Connect to office WiFi'
              ? false
              : state.allowed,
        ),
      );
      return;
    }
    await load();
    await verify();
  }
}

class HomeCubit extends AttendanceCubit {
  HomeCubit(super.actions);
  @override
  bool get currentMonth => true;
}

class HistoryCubit extends AttendanceCubit {
  HistoryCubit(super.actions);
}
