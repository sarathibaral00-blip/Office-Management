import 'package:bloc/bloc.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/holidays.dart';
import '../../domain/usecases/holidays_actions.dart';

class HolidaysCubit extends Cubit<FlowState<HolidayData>> {
  HolidaysCubit(this.actions) : super(const FlowState());
  final HolidaysActions actions;
  int year = DateTime.now().year;
  int generation = 0;
  Future<void> load() async {
    final g = ++generation;
    emit(FlowState(status: LoadStatus.loading, data: state.data));
    final r = await actions.load(year);
    if (!isClosed && g == generation) {
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
    String name,
    DateTime day,
    String? branch,
    bool active,
  ) async {
    if (state.busy) return false;
    emit(FlowState(status: state.status, data: state.data, busy: true));
    final r = await actions.save(id, name, day, branch, active);
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
}
