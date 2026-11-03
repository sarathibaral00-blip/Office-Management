import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/financing.dart';
import '../../domain/usecases/financing_actions.dart';

class FinancingCubit extends Cubit<FlowState<FinancingData>> {
  FinancingCubit(this.actions) : super(const FlowState());
  final FinancingActions actions;
  Future<void> load() async {
    emit(FlowState(status: LoadStatus.loading, data: state.data));
    final r = await actions.load();
    if (!isClosed) {
      emit(
        FlowState(
          status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
          data: r.value,
          message: r.failure?.message,
        ),
      );
    }
  }

  Future<bool> run(Future<Result<void>> Function() work) async {
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
    return true;
  }

  Future<bool> request(
    String kind,
    double amount,
    int count,
    DateTime month,
    String reason,
  ) => run(() => actions.request(kind, amount, count, month, reason));
  Future<bool> review(String id, String action, String comment) =>
      run(() => actions.review(id, action, comment));
}
