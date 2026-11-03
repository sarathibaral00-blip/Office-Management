import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/dashboards.dart';
import '../../domain/usecases/dashboards_actions.dart';

class DashboardsCubit extends Cubit<FlowState<DashboardData>> {
  DashboardsCubit(this.actions) : super(const FlowState());
  final DashboardsActions actions;
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
}
