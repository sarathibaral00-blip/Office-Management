import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/fallback.dart';
import '../../domain/usecases/support_actions.dart';

class SupportState extends Equatable {
  const SupportState({
    this.status = LoadStatus.initial,
    this.snapshot,
    this.record,
    this.message,
    this.busy = false,
    this.paired = false,
    this.revision = 0,
  });
  final LoadStatus status;
  final SupportSnapshot? snapshot;
  final SupportRecord? record;
  final String? message;
  final bool busy, paired;
  final int revision;
  @override
  List<Object?> get props => [
    status,
    snapshot,
    record,
    message,
    busy,
    paired,
    revision,
  ];
}

class SupportCubit extends Cubit<SupportState> {
  SupportCubit(this.actions) : super(const SupportState());
  final SupportActions actions;
  Future<void> load() async {
    emit(SupportState(status: LoadStatus.loading, snapshot: state.snapshot));
    final r = await actions.snapshot();
    if (isClosed) return;
    emit(
      SupportState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        snapshot: r.value,
        paired: actions.pairing != null,
        message: r.failure?.message,
      ),
    );
  }

  Future<bool> manage(String action, Map<String, Object?> data) async {
    if (state.busy) return false;
    emit(
      SupportState(status: state.status, snapshot: state.snapshot, busy: true),
    );
    final r = await actions.manage(action, data);
    if (isClosed) return false;
    if (r.failure != null) {
      emit(
        SupportState(
          status: LoadStatus.failure,
          snapshot: state.snapshot,
          message: r.failure!.message,
        ),
      );
      return false;
    }
    final snapshot = await actions.snapshot();
    if (isClosed) return false;
    emit(
      SupportState(
        status: snapshot.failure == null
            ? LoadStatus.success
            : LoadStatus.failure,
        snapshot: snapshot.value ?? state.snapshot,
        message: snapshot.failure?.message ?? 'Saved successfully',
        paired: actions.pairing != null,
      ),
    );
    return true;
  }
}

class ManualCubit extends SupportCubit {
  ManualCubit(super.actions);
  int lookup = 0;
  Future<void> find(String employee, DateTime day) async {
    final generation = ++lookup;
    emit(
      SupportState(status: state.status, snapshot: state.snapshot, busy: true),
    );
    final r = await actions.record(employee, day);
    if (isClosed || generation != lookup) return;
    emit(
      SupportState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        snapshot: state.snapshot,
        record: r.value,
        message:
            r.failure?.message ??
            (r.value == null
                ? 'No record found. You can add one.'
                : 'Existing record loaded.'),
        revision: r.failure == null ? state.revision + 1 : state.revision,
      ),
    );
  }

  Future<bool> submit(ManualSubmission s) async {
    if (state.busy) return false;
    emit(
      SupportState(
        status: state.status,
        snapshot: state.snapshot,
        record: state.record,
        busy: true,
      ),
    );
    final r = await actions.manual(s);
    if (isClosed) return false;
    if (r.failure != null) {
      emit(
        SupportState(
          status: LoadStatus.failure,
          snapshot: state.snapshot,
          record: state.record,
          message: r.failure!.message,
        ),
      );
      return false;
    }
    final updated = await actions.snapshot();
    if (isClosed) return false;
    emit(
      SupportState(
        status: LoadStatus.success,
        snapshot: updated.value ?? state.snapshot,
        message: r.value!.exceeded
            ? 'Saved. Monthly limit exceeded (${r.value!.count}/${r.value!.limit}); HR was notified.'
            : 'Manual attendance saved.',
      ),
    );
    return true;
  }
}

class DevicesCubit extends SupportCubit {
  DevicesCubit(super.actions);
}

class ReportState extends Equatable {
  const ReportState({
    this.status = LoadStatus.initial,
    this.records = const [],
    this.snapshot,
    this.hasMore = false,
    this.message,
    this.loadingMore = false,
  });
  final LoadStatus status;
  final List<SupportRecord> records;
  final SupportSnapshot? snapshot;
  final bool hasMore, loadingMore;
  final String? message;
  @override
  List<Object?> get props => [
    status,
    records,
    snapshot,
    hasMore,
    message,
    loadingMore,
  ];
}

class ReportCubit extends Cubit<ReportState> {
  ReportCubit(this.actions) : super(const ReportState());
  final SupportActions actions;
  int generation = 0;
  DateTime month = DateTime.now();
  Future<void> load(DateTime m) async {
    month = m;
    final g = ++generation;
    emit(const ReportState(status: LoadStatus.loading));
    final snapshot = await actions.snapshot();
    if (isClosed || g != generation) return;
    if (snapshot.failure != null) {
      emit(
        ReportState(
          status: LoadStatus.failure,
          message: snapshot.failure!.message,
        ),
      );
      return;
    }
    final r = await actions.report(m, 0);
    if (isClosed || g != generation) return;
    emit(
      ReportState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        snapshot: snapshot.value,
        records: r.value?.records ?? [],
        hasMore: r.value?.hasMore ?? false,
        message: r.failure?.message,
      ),
    );
  }

  Future<void> more() async {
    if (!state.hasMore || state.loadingMore) return;
    final g = generation;
    emit(
      ReportState(
        status: state.status,
        snapshot: state.snapshot,
        records: state.records,
        hasMore: state.hasMore,
        loadingMore: true,
      ),
    );
    final r = await actions.report(month, state.records.length);
    if (isClosed || g != generation) return;
    emit(
      ReportState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        snapshot: state.snapshot,
        records: [...state.records, ...?r.value?.records],
        hasMore: r.value?.hasMore ?? state.hasMore,
        message: r.failure?.message,
      ),
    );
  }
}

class KioskState extends Equatable {
  const KioskState({
    this.status = LoadStatus.initial,
    this.pairing,
    this.message,
  });
  final LoadStatus status;
  final DevicePairing? pairing;
  final String? message;
  @override
  List<Object?> get props => [status, pairing, message];
}

class KioskCubit extends Cubit<KioskState> {
  KioskCubit(this.actions)
    : super(KioskState(status: LoadStatus.success, pairing: actions.pairing));
  final SupportActions actions;
  Future<void> punch(DeviceSubmission s) async {
    if (state.status == LoadStatus.loading) return;
    final pairing = actions.pairing;
    if (pairing == null ||
        (pairing.expiresAt != null &&
            !pairing.expiresAt!.isAfter(DateTime.now()))) {
      actions.clearPairing();
      emit(
        const KioskState(
          status: LoadStatus.failure,
          message: 'Device approval expired. Ask HR to pair this device.',
        ),
      );
      return;
    }
    emit(KioskState(status: LoadStatus.loading, pairing: pairing));
    final r = await actions.devicePunch(s);
    if (isClosed) return;
    emit(
      KioskState(
        status: r.failure == null ? LoadStatus.success : LoadStatus.failure,
        pairing: pairing,
        message:
            r.failure?.message ??
            (s.action == 'check_in'
                ? 'You’re checked in. Have a great day!'
                : 'You’re checked out. See you next time!'),
      ),
    );
  }

  void clear() {
    actions.clearPairing();
    emit(const KioskState(status: LoadStatus.success));
  }
}
