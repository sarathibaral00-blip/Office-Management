import 'package:equatable/equatable.dart';
import 'package:bloc/bloc.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/network.dart';
import '../../domain/usecases/network_actions.dart';

class NetworkState extends Equatable {
  const NetworkState({
    this.status = LoadStatus.initial,
    this.data,
    this.message,
    this.currentIp,
    this.busy = false,
  });
  final LoadStatus status;
  final NetworkList? data;
  final String? message, currentIp;
  final bool busy;
  @override
  List<Object?> get props => [status, data, message, currentIp, busy];
}

class NetworkCubit extends Cubit<NetworkState> {
  NetworkCubit(this.actions) : super(const NetworkState());
  final NetworkActions actions;
  Future<void> load() async {
    emit(NetworkState(status: LoadStatus.loading, data: state.data));
    final r = await actions.list();
    if (isClosed) return;
    emit(
      NetworkState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        data: r.value,
        message: r.failure?.message,
      ),
    );
  }

  Future<bool> save({
    String? id,
    required String label,
    required String network,
    required String branchId,
    required bool active,
  }) async {
    if (state.busy) return false;
    emit(NetworkState(status: state.status, data: state.data, busy: true));
    final r = await actions.save(
      id: id,
      label: label,
      network: network,
      branchId: branchId,
      active: active,
    );
    if (isClosed) return false;
    if (r.failure != null) {
      emit(
        NetworkState(
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

  Future<void> delete(String id) async {
    final r = await actions.delete(id);
    if (isClosed) return;
    if (r.failure != null) {
      emit(
        NetworkState(
          status: LoadStatus.failure,
          data: state.data,
          message: r.failure!.message,
        ),
      );
    } else {
      await load();
    }
  }

  Future<String?> currentIp() async {
    final r = await actions.currentIp();
    if (isClosed) return null;
    emit(
      NetworkState(
        status: state.status,
        data: state.data,
        currentIp: r.value,
        message: r.failure?.message,
      ),
    );
    return r.value;
  }

  Future<bool> createBranch(String name) async {
    if (state.busy) return false;
    if (name.trim().isEmpty || name.trim().length > 100) {
      emit(
        NetworkState(
          status: LoadStatus.failure,
          data: state.data,
          message: 'Enter a branch name between 1 and 100 characters.',
        ),
      );
      return false;
    }
    emit(NetworkState(status: state.status, data: state.data, busy: true));
    final result = await actions.createBranch(name.trim());
    if (isClosed) return false;
    if (result.failure != null) {
      emit(
        NetworkState(
          status: LoadStatus.failure,
          data: state.data,
          message: result.failure!.message,
        ),
      );
      return false;
    }
    final previous = state.data;
    final branches = [...?previous?.branches, result.value!]
      ..sort((a, b) => a.name.compareTo(b.name));
    emit(
      NetworkState(
        status: LoadStatus.success,
        data: NetworkList(previous?.networks ?? [], branches),
      ),
    );
    return true;
  }
}
