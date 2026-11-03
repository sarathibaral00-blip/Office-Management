import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/notifications.dart';
import '../../domain/usecases/notifications_actions.dart';

class NotificationsCubit extends Cubit<FlowState<InboxData>> {
  NotificationsCubit(this.actions) : super(const FlowState());
  final NotificationsActions actions;
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

  Future<void> read(String? id) async {
    if (state.busy) return;
    emit(FlowState(status: state.status, data: state.data, busy: true));
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
