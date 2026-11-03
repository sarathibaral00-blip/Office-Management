import 'package:bloc/bloc.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/notices.dart';
import '../../domain/usecases/notices_actions.dart';

class NoticesCubit extends Cubit<FlowState<NoticeData>> {
  NoticesCubit(this.actions) : super(const FlowState());
  final NoticesActions actions;
  int _loadVersion = 0;
  Future<void> load() async {
    final version = ++_loadVersion;
    emit(FlowState(status: LoadStatus.loading, data: state.data));
    final r = await actions.load();
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

  Future<bool> save(
    String? id,
    String title,
    String body,
    String? department,
    bool active,
  ) async {
    if (state.busy) return false;
    emit(FlowState(status: state.status, data: state.data, busy: true));
    final r = await actions.save(id, title, body, department, active);
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

  Future<void> read(String id) async {
    final r = await actions.read(id);
    if (isClosed) return;
    if (r.failure == null) {
      await load();
    } else {
      emit(
        FlowState(
          status: LoadStatus.failure,
          data: state.data,
          message: r.failure!.message,
        ),
      );
    }
  }
}
