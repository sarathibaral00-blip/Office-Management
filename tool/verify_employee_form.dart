// Exercises the real employee form with fake repositories; creates no live data.
import 'dart:io' show stdout, exit;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr_management/core/domain/page_result.dart';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/core/widgets/app_widgets.dart';
import 'package:hr_management/core/widgets/choice_field.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:hr_management/features/auth/domain/usecases/auth_actions.dart';
import 'package:hr_management/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:hr_management/features/employees/domain/entities/employees.dart';
import 'package:hr_management/features/employees/domain/usecases/employees_actions.dart';
import 'package:hr_management/features/employees/presentation/bloc/employees_cubit.dart';
import 'package:hr_management/features/employees/presentation/pages/employees_page.dart';
import '../test/support/scenarios.dart' show FakeAuth;
import '../test/support/workflow_scenarios.dart' show FakeEmployees;

class _Employees extends FakeEmployees {
  int saves = 0;
  Map<String, Object?>? saved;
  @override
  Future<Result<void>> create(Map<String, Object?> data) async {
    saves++;
    saved = data;
    return saves == 1
        ? const Result.failure(Failure('Duplicate email'))
        : const Result.success(null);
  }
}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  Future<void> frame() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    binding.scheduleFrame();
    await binding.endOfFrame;
  }

  void check(bool value, String reason) {
    if (!value) throw StateError(reason);
  }

  List<T> widgets<T extends Widget>() {
    final found = <T>[];
    void visit(Element element) {
      if (element.widget is T) found.add(element.widget as T);
      element.visitChildren(visit);
    }

    visit(binding.rootElement!);
    return found;
  }

  VoidCallback action(String label) {
    VoidCallback? result;
    void visit(Element element) {
      if (element.widget case AppText(data: final data) when data == label) {
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget is ButtonStyleButton) {
            result = (ancestor.widget as ButtonStyleButton).onPressed;
            return false;
          }
          return true;
        });
      }
      element.visitChildren(visit);
    }

    visit(binding.rootElement!);
    return result!;
  }

  final authRepository = FakeAuth();
  final auth = AuthCubit(AuthActions(authRepository));
  final repo = _Employees();
  final detail = EmployeeDetailCubit(EmployeesActions(repo));
  final home = GlobalKey();
  runApp(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      enableScaleWH: () => false,
      builder: (_, _) => MaterialApp(
        home: Scaffold(body: SizedBox(key: home)),
      ),
    ),
  );
  await frame();
  var closed = false;
  Navigator.of(home.currentContext!)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider.value(value: detail),
            ],
            child: const EmployeeDetailPage(
              directory: Directory(PageResult([], false), [], [], [], []),
            ),
          ),
        ),
      )
      .then((_) => closed = true);
  await frame();
  void setField(String label, String value) {
    widgets<AppTextField>()
            .singleWhere((w) => w.label == label)
            .controller
            .text =
        value;
  }

  void save() => widgets<AppButton>()
      .singleWhere((w) => w.label == 'Save employee')
      .onPressed!();
  save();
  await frame();
  check(repo.saves == 0, 'Empty employee form submitted');
  setField('Full name', 'UI Test Employee');
  setField('Work email', 'invalid-email');
  setField('Initial password (6 digits)', '12345');
  setField('Salary', '1000');
  save();
  await frame();
  check(repo.saves == 0, 'Invalid email/password submitted');
  setField('Work email', 'ui-test@example.invalid');
  setField('Initial password (6 digits)', '654321');
  save();
  await frame();
  check(repo.saves == 1 && !closed, 'Failed save dismissed form');
  check(
    widgets<AppTextField>()
            .singleWhere((w) => w.label == 'Initial password (6 digits)')
            .controller
            .text
            .length ==
        6,
    'Failed save cleared the password',
  );
  check(
    widgets<AppText>().any((w) => w.data == 'Duplicate email'),
    'Save error missing',
  );
  action('Add department')();
  await frame();
  widgets<EditableText>().last.controller.text = 'Engineering';
  widgets<FilledButton>().last.onPressed!();
  await frame();
  check(
    widgets<ChoiceField>().singleWhere((w) => w.label == 'Department').value ==
        'department-new',
    'Created department was not selected',
  );
  save();
  await frame();
  check(
    repo.saves == 2 && closed,
    'Successful save did not close employee page',
  );
  check(
    repo.saved?['department_id'] == 'department-new',
    'Selected department not saved',
  );
  check(
    repo.saved?['password'] == '654321',
    'Six-digit password not passed to repository',
  );
  if (errors.isNotEmpty) throw StateError(errors.join('\n'));
  await detail.close();
  await auth.close();
  await authRepository.events.close();
  stdout.writeln(
    'PASS: real employee form validation, six-digit password, failed-save recovery, inline error, department creation/selection and successful save',
  );
  exit(0);
}
