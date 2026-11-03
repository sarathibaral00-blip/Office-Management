// Standalone engine checks: validation, retry, duplicate submission and dismissal.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr_management/core/widgets/app_action_dialog.dart';

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
  List<T> widgets<T extends Widget>() {
    final found = <T>[];
    void visit(Element element) {
      if (element.widget is T) found.add(element.widget as T);
      element.visitChildren(visit);
    }

    visit(binding.rootElement!);
    return found;
  }

  var submissions = 0;
  final pending = Completer<String?>();
  final result = showAppActionDialog(
    context: home.currentContext!,
    title: 'Approve leave',
    label: 'Review comment',
    onConfirm: (value) async {
      submissions++;
      return submissions == 1 ? 'Request is no longer pending' : pending.future;
    },
  );
  await frame();
  widgets<FilledButton>().single.onPressed!();
  await frame();
  check(submissions == 0, 'Blank review was submitted');
  check(
    widgets<Text>().any((w) => w.data == 'Enter at least 3 characters.'),
    'Missing inline validation',
  );
  widgets<EditableText>().single.controller.text = 'Reviewed and approved';
  widgets<FilledButton>().single.onPressed!();
  await frame();
  check(submissions == 1, 'Valid review was not submitted');
  check(
    widgets<Text>().any((w) => w.data == 'Request is no longer pending'),
    'Server error is not visible inside the open dialog',
  );
  final submit = widgets<FilledButton>().single.onPressed!;
  submit();
  submit();
  await frame();
  check(submissions == 2, 'Double click submitted the request twice');
  check(
    widgets<FilledButton>().single.onPressed == null,
    'Submit stays enabled',
  );
  check(widgets<TextButton>().single.onPressed == null, 'Cancel stays enabled');
  pending.complete(null);
  check(await result, 'Successful retry did not confirm');
  await frame();
  check(widgets<AlertDialog>().isEmpty, 'Success left the dialog open');
  final cancelled = showAppActionDialog(
    context: home.currentContext!,
    title: 'Reject leave',
    label: 'Review comment',
    onConfirm: (_) async {
      throw StateError('Cancellation submitted');
    },
  );
  await frame();
  widgets<TextButton>().single.onPressed!();
  check(!await cancelled, 'Cancel returned success');
  await frame();
  if (errors.isNotEmpty) throw StateError(errors.join('\n'));
  stdout.writeln(
    'PASS: blank-comment validation, server error, retry, duplicate-click prevention, busy controls, success and cancellation',
  );
  exit(0);
}
