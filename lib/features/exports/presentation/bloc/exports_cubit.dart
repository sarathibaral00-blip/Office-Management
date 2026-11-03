import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/exports.dart';
import '../../domain/usecases/exports_actions.dart';

class ExportsCubit extends Cubit<FlowState<ExportOptions>> {
  ExportsCubit(this.actions) : super(const FlowState());
  final ExportsActions actions;
  Future<void> load() async {
    emit(const FlowState(status: LoadStatus.loading));
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

  Future<void> export(
    String kind,
    DateTime start,
    DateTime end,
    String? department,
    String? branch,
    String format,
    bool share,
  ) async {
    if (state.busy) return;
    emit(FlowState(status: state.status, data: state.data, busy: true));
    final r = await actions.export(
      kind,
      start,
      end,
      department,
      branch,
      format,
      share,
    );
    if (!isClosed) {
      emit(
        FlowState(
          status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
          data: state.data,
          message: r.failure?.message ?? 'Export completed or cancelled',
        ),
      );
    }
  }
}
