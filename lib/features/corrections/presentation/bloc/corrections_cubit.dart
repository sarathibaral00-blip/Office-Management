import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/corrections.dart';
import '../../domain/usecases/corrections_actions.dart';

class CorrectionsCubit extends Cubit<FlowState<CorrectionData>> {
  CorrectionsCubit(this.actions) : super(const FlowState());
  final CorrectionsActions actions;
  int _loadVersion = 0;
  int year = DateTime.now().year;
  Future<void> load() async {
    final version = ++_loadVersion;
    emit(FlowState(status: LoadStatus.loading, data: state.data));
    final r = await actions.load(year);
    if (!isClosed && version == _loadVersion) {
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
    String id,
    DateTime start,
    DateTime? end,
    String reason,
  ) => run(() => actions.request(id, start, end, reason));
  Future<bool> review(String id, bool approve, String comment) =>
      run(() => actions.review(id, approve, comment));
}
