import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/expenses.dart';
import '../../domain/usecases/expenses_actions.dart';

class ExpensesCubit extends Cubit<FlowState<ExpenseData>> {
  ExpensesCubit(this.actions) : super(const FlowState());
  final ExpensesActions actions;
  String? receiptPath;
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
          message: 'Expense updated',
        ),
      );
    }
    return true;
  }

  Future<void> upload() async {
    if (state.busy) return;
    emit(FlowState(status: state.status, data: state.data, busy: true));
    final r = await actions.upload();
    if (isClosed) return;
    receiptPath = r.value ?? receiptPath;
    emit(
      FlowState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        data: state.data,
        message:
            r.failure?.message ??
            (r.value == null ? 'Selection cancelled' : 'Receipt uploaded'),
      ),
    );
  }

  Future<bool> submit(
    String title,
    String category,
    double amount,
    DateTime day,
  ) async {
    if (receiptPath == null) {
      emit(
        FlowState(
          status: LoadStatus.failure,
          data: state.data,
          message: 'Upload a receipt first',
        ),
      );
      return false;
    }
    final ok = await run(
      () => actions.submit(title, category, amount, day, receiptPath!),
    );
    if (ok) receiptPath = null;
    return ok;
  }

  Future<bool> review(String id, String action, String comment) =>
      run(() => actions.review(id, action, comment));
  Future<bool> receipt(String path) =>
      run(() => actions.receipt(path), reload: false);
}
