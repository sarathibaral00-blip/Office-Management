import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/documents.dart';
import '../../domain/usecases/documents_actions.dart';

class DocumentsCubit extends Cubit<FlowState<DocumentData>> {
  DocumentsCubit(this.actions) : super(const FlowState());
  final DocumentsActions actions;
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

  Future<void> run(
    Future<Result<void>> Function() work, {
    bool reload = true,
  }) async {
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
    if (reload) await load();
    if (!isClosed) {
      emit(
        FlowState(
          status: state.status,
          data: state.data,
          message: 'Document action completed or cancelled',
        ),
      );
    }
  }

  Future<void> upload(String employee, String kind, String title) =>
      run(() => actions.upload(employee, kind, title));
  Future<void> download(String path, String title) =>
      run(() => actions.download(path, title), reload: false);
}
