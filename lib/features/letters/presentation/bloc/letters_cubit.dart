import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/letters.dart';
import '../../domain/usecases/letters_actions.dart';

class LettersCubit extends Cubit<FlowState<LetterData>> {
  LettersCubit(this.actions) : super(const FlowState());
  final LettersActions actions;
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

  Future<void> run(Future<Result<void>> Function() work) async {
    if (state.busy) return;
    emit(FlowState(status: state.status, data: state.data, busy: true));
    final r = await work();
    if (isClosed) return;
    if (r.failure != null) {
      emit(
        FlowState(
          status: LoadStatus.failure,
          data: state.data,
          message: r.failure!.message,
        ),
      );
      return;
    }
    await load();
    if (!isClosed) {
      emit(
        FlowState(
          status: state.status,
          data: state.data,
          message: 'Letter saved; download/share completed or cancelled',
        ),
      );
    }
  }

  Future<void> issue(String id, String kind, String purpose) =>
      run(() => actions.issue(id, kind, purpose));
  Future<void> export(String id, bool share) =>
      run(() => actions.export(id, share));
}
