import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/profile.dart';
import '../../domain/usecases/profile_actions.dart';

class ProfileCubit extends Cubit<FlowState<MyProfile>> {
  ProfileCubit(this.actions) : super(const FlowState());
  final ProfileActions actions;
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
          message: state.status == LoadStatus.failure
              ? state.message
              : 'Profile updated',
        ),
      );
    }
  }

  Future<void> phone(String phone) => run(() => actions.phone(phone));
  Future<void> photo() => run(actions.photo);
  Future<void> password(String password) =>
      run(() => actions.password(password));
}
