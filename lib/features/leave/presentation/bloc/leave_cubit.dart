import 'package:bloc/bloc.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/leave.dart';
import '../../domain/usecases/leave_actions.dart';

class LeaveCubit extends Cubit<FlowState<LeaveData>> {
  LeaveCubit(this.actions) : super(const FlowState());
  final LeaveActions actions;
  int year = DateTime.now().year;
  int generation = 0;
  Future<void> load() async {
    final g = ++generation;
    emit(FlowState(status: LoadStatus.loading, data: state.data));
    final r = await actions.load(year);
    if (!isClosed && g == generation) {
      emit(
        FlowState(
          status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
          data: r.value,
          message: r.failure?.message,
        ),
      );
    }
  }

  Future<bool> mutate(Future<Result<void>> Function() work) async {
    if (state.busy) return false;
    emit(FlowState(status: state.status, data: state.data, busy: true));
    final r = await work();
    if (isClosed) return false;
    if (r.failure != null) {
      emit(
        FlowState(
          status: LoadStatus.failure,
          data: state.data,
          message: r.failure!.message,
        ),
      );
      return false;
    }
    await load();
    if (!isClosed) {
      emit(
        FlowState(
          status: state.status,
          data: state.data,
          message: state.status == LoadStatus.failure
              ? state.message
              : 'Leave updated',
        ),
      );
    }
    return true;
  }

  Future<bool> apply(
    String type,
    DateTime start,
    DateTime end,
    bool half,
    String? period,
    String reason,
  ) => mutate(() => actions.apply(type, start, end, half, period, reason));
  Future<bool> cancel(String id) => mutate(() => actions.cancel(id));
  Future<bool> review(String id, bool approve, String comment) =>
      mutate(() => actions.review(id, approve, comment));
}
