import 'package:bloc/bloc.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../../core/domain/page_result.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/employees.dart';
import '../../domain/usecases/employees_actions.dart';

class EmployeesCubit extends Cubit<FlowState<Directory>> {
  EmployeesCubit(this.actions) : super(const FlowState());
  final EmployeesActions actions;
  int generation = 0, offset = 0;
  String search = '';
  String? department, branch;
  bool? active;
  Future<void> load({bool more = false}) async {
    if (more && state.busy) return;
    final g = ++generation;
    final previous = state.data;
    emit(
      FlowState(
        status: more ? state.status : LoadStatus.loading,
        data: previous,
        busy: true,
      ),
    );
    final next = more ? offset + 25 : 0;
    final r = await actions.list(search, department, branch, active, next);
    if (isClosed || g != generation) return;
    offset = r.failure == null ? next : offset;
    final data = r.value;
    emit(
      FlowState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        data: data == null
            ? previous
            : more && previous != null
            ? Directory(
                PageResult([
                  ...previous.page.items,
                  ...data.page.items,
                ], data.page.hasMore),
                data.departments,
                data.branches,
                data.managers,
                data.shifts,
              )
            : data,
        message: r.failure?.message,
      ),
    );
  }
}

class EmployeeDetailCubit extends Cubit<FlowState<Staff>> {
  EmployeeDetailCubit(this.actions) : super(const FlowState());
  final EmployeesActions actions;
  Future<void> load(String id) async {
    emit(const FlowState(status: LoadStatus.loading));
    final r = await actions.detail(id);
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

  Future<bool> save(String? id, Map<String, Object?> data) async {
    if (state.busy) return false;
    emit(FlowState(status: state.status, data: state.data, busy: true));
    final r = id == null
        ? await actions.create(data)
        : await actions.update(id, data);
    if (isClosed) return false;
    emit(
      FlowState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        data: state.data,
        message: r.failure?.message ?? 'Employee saved',
      ),
    );
    return r.failure == null;
  }

  Future<Choice?> createDepartment(String name) async {
    if (state.busy) return null;
    emit(FlowState(status: state.status, data: state.data, busy: true));
    final r = await actions.createDepartment(name);
    if (isClosed) return null;
    emit(
      FlowState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        data: state.data,
        message: r.failure?.message ?? 'Department added',
      ),
    );
    return r.value;
  }

  Future<void> pin(String id, String pin) async {
    emit(FlowState(status: state.status, data: state.data, busy: true));
    final r = await actions.pin(id, pin);
    if (!isClosed) {
      emit(
        FlowState(
          status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
          data: state.data,
          message: r.failure?.message ?? 'PIN reset securely',
        ),
      );
    }
  }
}
