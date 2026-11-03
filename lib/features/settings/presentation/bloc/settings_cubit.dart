import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/settings.dart';
import '../../domain/usecases/settings_actions.dart';

class SettingsCubit extends Cubit<FlowState<SettingsData>> {
  SettingsCubit(this.actions) : super(const FlowState());
  final SettingsActions actions;
  int offset = 0;
  Future<void> load({bool more = false}) async {
    final previous = state.data;
    emit(FlowState(status: LoadStatus.loading, data: previous));
    final next = more ? offset + 50 : 0;
    final r = await actions.load(next);
    if (isClosed) return;
    final d = r.value;
    if (d != null) offset = next;
    emit(
      FlowState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        data: d == null
            ? previous
            : more && previous != null
            ? SettingsData(d.company, d.shifts, d.permissions, [
                ...previous.audit,
                ...d.audit,
              ], d.auditMore)
            : d,
        message: r.failure?.message,
      ),
    );
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
          message: 'Settings saved',
        ),
      );
    }
  }

  Future<void> company(Map<String, Object?> data) =>
      run(() => actions.company(data));
  Future<void> asset(String kind) => run(() => actions.asset(kind));
  Future<void> shift(String? id, Map<String, Object?> data) =>
      run(() => actions.shift(id, data));
  Future<void> permission(String role, String key, bool enabled) =>
      run(() => actions.permission(role, key, enabled));
}
