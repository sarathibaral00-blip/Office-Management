import 'package:bloc/bloc.dart';
import '../../../../core/domain/page_result.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/attendance_reports.dart';
import '../../domain/usecases/attendance_reports_actions.dart';

class AttendanceReportsCubit extends Cubit<FlowState<AttendanceReportData>> {
  AttendanceReportsCubit(this.actions) : super(const FlowState());
  final AttendanceReportsActions actions;
  DateTime day = DateTime.now();
  bool monthly = false;
  String? department, branch;
  int offset = 0, generation = 0;
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
    final next = more ? offset + 50 : 0;
    final start = monthly
        ? DateTime(day.year, day.month)
        : DateTime(day.year, day.month, day.day);
    final end = monthly ? DateTime(day.year, day.month + 1, 0) : start;
    final r = await actions.load(start, end, department, branch, next);
    if (isClosed || g != generation) return;
    final d = r.value;
    if (d != null) offset = next;
    emit(
      FlowState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        data: d == null
            ? previous
            : more && previous != null
            ? AttendanceReportData(
                PageResult([
                  ...previous.page.items,
                  ...d.page.items,
                ], d.page.hasMore),
                d.departments,
                d.branches,
                d.total,
                d.present,
                d.late,
                d.absent,
                d.hours,
              )
            : d,
        message: r.failure?.message,
      ),
    );
  }
}
