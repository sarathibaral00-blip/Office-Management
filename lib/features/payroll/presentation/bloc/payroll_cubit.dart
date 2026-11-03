import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/payroll.dart';
import '../../domain/usecases/payroll_actions.dart';

class PayrollCubit extends Cubit<FlowState<PayrollData>> {
  PayrollCubit(this.actions) : super(const FlowState());
  final PayrollActions actions;
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

  Future<bool> run(
    Future<Result<void>> Function() work, {
    bool reload = true,
  }) async {
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
    if (reload) await load();
    if (!isClosed) {
      emit(
        FlowState(
          status: state.status,
          data: state.data,
          message: reload ? 'Payroll updated' : 'Export completed or cancelled',
        ),
      );
    }
    return true;
  }

  Future<bool> generate(DateTime month) => run(() => actions.generate(month));
  Future<bool> transition(String id, String action) =>
      run(() => actions.transition(id, action));
  Future<bool> salary(String id, Map<String, Object?> values) =>
      run(() => actions.salary(id, values));
  Future<bool> adjust(String id, double bonus, double extra, String reason) =>
      run(() => actions.adjust(id, bonus, extra, reason));
  Future<bool> payslip(String id, bool share) =>
      run(() => actions.payslip(id, share), reload: false);
  Future<bool> bank(String runId) =>
      run(() => actions.bank(runId), reload: false);
}
