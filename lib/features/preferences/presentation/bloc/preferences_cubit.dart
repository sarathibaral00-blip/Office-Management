import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/preferences.dart';
import '../../domain/usecases/preferences_actions.dart';

class PreferencesCubit extends Cubit<FlowState<UiPreferences>> {
  PreferencesCubit(this.actions)
    : super(const FlowState(data: UiPreferences()));
  final PreferencesActions actions;
  Future<void> load() async {
    final r = await actions.load();
    if (!isClosed) {
      emit(
        FlowState(
          status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
          data: r.value ?? const UiPreferences(),
          message: r.failure?.message,
        ),
      );
    }
  }

  Future<void> save(String language, String theme) async {
    if (state.busy) return;
    final old = state.data ?? const UiPreferences();
    emit(FlowState(status: state.status, data: old, busy: true));
    final next = UiPreferences(language: language, theme: theme);
    final r = await actions.save(next);
    if (!isClosed) {
      emit(
        FlowState(
          status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
          data: r.failure == null ? next : old,
          message: r.failure?.message,
        ),
      );
    }
  }
}
