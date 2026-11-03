import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:hr_management/core/domain/page_result.dart';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/core/export/report_data.dart';
import 'package:hr_management/core/export/tabular_codec.dart';
import 'package:hr_management/core/export/file_validation.dart';
import 'package:hr_management/features/payroll/domain/entities/payroll.dart';
import 'package:hr_management/features/payroll/domain/repositories/payroll_repository.dart';
import 'package:hr_management/features/payroll/domain/usecases/payroll_actions.dart';
import 'package:hr_management/features/payroll/presentation/bloc/payroll_cubit.dart';
import 'package:hr_management/features/preferences/domain/entities/preferences.dart';
import 'package:hr_management/features/preferences/domain/repositories/preferences_repository.dart';
import 'package:hr_management/features/preferences/domain/usecases/preferences_actions.dart';
import 'package:hr_management/features/preferences/presentation/bloc/preferences_cubit.dart';
import 'scenarios.dart' show expectEqual;

class FakePayroll implements PayrollRepository {
  static const initial = PayrollData([], [], [Choice('employee', 'Amina')], {});
  final pendingLoads = <Completer<Result<PayrollData>>>[];
  bool delayed = false;
  int transitions = 0, generations = 0;
  final transitionResult = Completer<Result<void>>();
  @override
  Future<Result<PayrollData>> load(int year) {
    if (!delayed) return Future.value(const Result.success(initial));
    final c = Completer<Result<PayrollData>>();
    pendingLoads.add(c);
    return c.future;
  }

  @override
  Future<Result<void>> generate(DateTime month) async {
    generations++;
    return const Result.failure(
      Failure('Resolve open attendance before running payroll'),
    );
  }

  @override
  Future<Result<void>> transition(String run, String action) {
    transitions++;
    return transitionResult.future;
  }

  @override
  Future<Result<void>> salary(
    String employee,
    Map<String, Object?> values,
  ) async => const Result.failure(
    Failure('You cannot change your own salary structure'),
  );
  @override
  Future<Result<void>> adjust(
    String id,
    double bonus,
    double extra,
    String reason,
  ) async => const Result.failure(Failure('Locked payslips are immutable'));
  @override
  Future<Result<void>> payslip(String id, bool share) async =>
      const Result.success(null);
  @override
  Future<Result<void>> bank(String run) async => const Result.failure(
    Failure('Lock the payroll run before exporting its bank sheet.'),
  );
}

class FakePreferences implements PreferencesRepository {
  @override
  Future<Result<UiPreferences>> load() async =>
      const Result.success(UiPreferences());
  @override
  Future<Result<void>> save(UiPreferences preferences) async =>
      const Result.failure(Failure('Display preferences could not be saved.'));
}

final Map<String, Future<void> Function()> payrollScenarios = {
  'Payroll generation failure preserves data and releases busy state':
      () async {
        final repo = FakePayroll();
        final c = PayrollCubit(PayrollActions(repo));
        await c.load();
        expectEqual(await c.generate(DateTime(2026, 9)), false);
        expectEqual(c.state.data, FakePayroll.initial);
        expectEqual(c.state.busy, false);
        expectEqual(
          c.state.message,
          'Resolve open attendance before running payroll',
        );
        await c.close();
      },
  'Payroll approval cannot be double submitted while the server is pending':
      () async {
        final repo = FakePayroll();
        final c = PayrollCubit(PayrollActions(repo));
        await c.load();
        final first = c.transition('run', 'approve');
        expectEqual(c.state.busy, true);
        expectEqual(await c.transition('run', 'approve'), false);
        expectEqual(repo.transitions, 1);
        repo.transitionResult.complete(const Result.success(null));
        expectEqual(await first, true);
        expectEqual(c.state.busy, false);
        await c.close();
      },
  'A server rejection cannot mark payroll approved or locked locally':
      () async {
        final repo = FakePayroll();
        final c = PayrollCubit(PayrollActions(repo));
        await c.load();
        final work = c.transition('run', 'lock');
        repo.transitionResult.complete(
          const Result.failure(Failure('Invalid payroll transition')),
        );
        expectEqual(await work, false);
        expectEqual(c.state.status, LoadStatus.failure);
        expectEqual(c.state.data, FakePayroll.initial);
        await c.close();
      },
  'Locked payroll adjustments and premature bank exports show server failures':
      () async {
        final c = PayrollCubit(PayrollActions(FakePayroll()));
        await c.load();
        expectEqual(await c.adjust('locked', 50, 0, 'Attempt'), false);
        expectEqual(c.state.message, 'Locked payslips are immutable');
        expectEqual(await c.bank('draft'), false);
        expectEqual(c.state.busy, false);
        await c.close();
      },
  'Latest payroll year wins when load responses arrive out of order': () async {
    final repo = FakePayroll()..delayed = true;
    final c = PayrollCubit(PayrollActions(repo));
    final first = c.load();
    c.year = 2025;
    final second = c.load();
    repo.pendingLoads[1].complete(const Result.success(FakePayroll.initial));
    await second;
    repo.pendingLoads[0].complete(
      const Result.success(PayrollData([], [], [], {})),
    );
    await first;
    expectEqual(c.state.data, FakePayroll.initial);
    await c.close();
  },
  'Own salary mutation errors are surfaced without optimistic salary changes':
      () async {
        final c = PayrollCubit(PayrollActions(FakePayroll()));
        await c.load();
        expectEqual(await c.salary('self', {'basic': 500}), false);
        expectEqual(c.state.data, FakePayroll.initial);
        expectEqual(
          c.state.message,
          'You cannot change your own salary structure',
        );
        await c.close();
      },
  'CSV quotes delimiters and neutralizes spreadsheet formula payloads':
      () async {
        final data = ReportData(
          title: 'Test',
          headers: const ['Name', 'Value'],
          rows: const [
            ['A, "B"', '=HYPERLINK("bad")'],
            ['বাংলা', '  +SUM(1,2)'],
            ['Tab', '\t=1+1'],
          ],
        );
        final value = utf8.decode(csvBytes(data));
        expectEqual(csvBytes(data).take(3).join(','), '239,187,191');
        expectEqual(value.contains('"A, ""B"""'), true);
        expectEqual(value.contains("'=HYPERLINK"), true);
        expectEqual(value.contains("'  +SUM"), true);
        expectEqual(value.contains("'\t=1+1"), true);
        expectEqual(value.contains('বাংলা'), true);
      },
  'Excel ZIP preserves numeric money, bank text and formula-like text':
      () async {
        final data = ReportData(
          title: 'Test',
          headers: const ['Name', 'Value'],
          rows: const [
            ['001234567890123456', 12.25],
            ['=1+1', 'বাংলা'],
          ],
        );
        final bytes = xlsxBytes(data);
        final zip = ZipDecoder().decodeBytes(bytes, verify: true);
        final sheet = utf8.decode(
          zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
        );
        expectEqual(sheet.contains('<v>12.25</v>'), true);
        expectEqual(sheet.contains('001234567890123456'), true);
        expectEqual(sheet.contains('=1+1'), true);
        expectEqual(sheet.contains('<f>'), false);
        expectEqual(zip.findFile('[Content_Types].xml') != null, true);
        expectEqual(columnName(26), 'AA');
      },
  'Private file validation rejects unknown content and oversized receipts':
      () async {
        expectEqual(
          privateFileFormat(
            Uint8List.fromList('%PDF-1.7 test'.codeUnits),
          )?.mime,
          'application/pdf',
        );
        expectEqual(
          privateFileFormat(Uint8List.fromList('<html>bad</html>'.codeUnits)),
          null,
        );
        expectEqual(privateFileFormat(Uint8List(10 * 1024 * 1024 + 1)), null);
      },
  'Failed preference persistence keeps the previous language and theme':
      () async {
        final c = PreferencesCubit(PreferencesActions(FakePreferences()));
        await c.load();
        await c.save('bn', 'dark');
        expectEqual(c.state.data, const UiPreferences());
        expectEqual(c.state.status, LoadStatus.failure);
        await c.close();
      },
};
