// Salary sheet UI checks with synthetic payroll data; no live salary changes.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr_management/core/domain/page_result.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:hr_management/core/widgets/choice_field.dart';
import 'package:hr_management/features/payroll/domain/entities/payroll.dart';
import 'package:hr_management/features/payroll/presentation/widgets/salary_structure_sheet.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  Future<void> frame() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    binding.scheduleFrame();
    await binding.endOfFrame;
  }

  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  List<T> widgets<T extends Widget>() {
    final values = <T>[];
    void visit(Element e) {
      if (e.widget is T) values.add(e.widget as T);
      e.visitChildren(visit);
    }

    visit(binding.rootElement!);
    return values;
  }

  final directory = Directory('/tmp/hr-salary-sheet');
  await directory.create(recursive: true);
  for (final sample in [
    (width: 390.0, height: 844.0, scale: 1.0, keyboard: 0.0, dark: false),
    (width: 320.0, height: 640.0, scale: 1.0, keyboard: 260.0, dark: false),
    (width: 390.0, height: 844.0, scale: 2.0, keyboard: 280.0, dark: false),
    (width: 1024.0, height: 768.0, scale: 1.0, keyboard: 0.0, dark: true),
  ]) {
    final home = GlobalKey(), capture = GlobalKey();
    var submits = 0;
    final pending = Completer<String?>();
    Map<String, Object?>? saved;
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: OverflowBox(
            maxWidth: sample.width,
            maxHeight: sample.height,
            child: SizedBox(
              width: sample.width,
              height: sample.height,
              child: RepaintBoundary(
                key: capture,
                child: MediaQuery(
                  data: MediaQueryData(size: Size(sample.width, sample.height)),
                  child: ScreenUtilInit(
                    key: UniqueKey(),
                    designSize: const Size(390, 844),
                    enableScaleWH: () => sample.width < 600,
                    fontSizeResolver: (size, util) =>
                        size * util.scaleWidth.clamp(.85, 1.2),
                    builder: (_, _) {
                      ScreenUtil.configure(
                        data: MediaQueryData(
                          size: Size(sample.width, sample.height),
                        ),
                        designSize: const Size(390, 844),
                      );
                      return MaterialApp(
                        debugShowCheckedModeBanner: false,
                        theme: ThemeData(
                          useMaterial3: true,
                          colorScheme: ColorScheme.fromSeed(
                            seedColor: const Color(0xFF800020),
                            primary: sample.dark
                                ? const Color(0xFFFFB1C1)
                                : const Color(0xFF800020),
                            brightness: sample.dark
                                ? Brightness.dark
                                : Brightness.light,
                          ),
                        ),
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: Size(sample.width, sample.height),
                            textScaler: TextScaler.linear(sample.scale),
                            viewInsets: EdgeInsets.only(
                              bottom: sample.keyboard,
                            ),
                          ),
                          child: child!,
                        ),
                        home: Scaffold(body: SizedBox(key: home)),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await frame();
    final result = showSalaryStructureSheet(
      context: home.currentContext!,
      data: const PayrollData(
        [],
        [],
        [Choice('employee', 'Amina Rahman')],
        {
          'employee': {
            'basic': 30000,
            'house_rent': 10000,
            'medical': 1500,
            'conveyance': 1000,
            'bank_name': 'Example Bank',
            'account_name': 'Amina Rahman',
            'account_number': '00123456789',
          },
        },
      ),
      onSave: (employee, values) async {
        submits++;
        saved = values;
        return submits == 1 ? 'Salary update was rejected' : pending.future;
      },
    );
    await frame();
    check(widgets<AlertDialog>().isEmpty, 'Salary still uses a dialog');
    widgets<FilledButton>().single.onPressed!();
    await frame();
    check(submits == 0, 'Missing employee submitted');
    widgets<ChoiceField>().single.onChanged!('employee');
    await frame();
    TextField field(String label) => widgets<TextField>().singleWhere(
      (w) => w.decoration?.labelText == label,
    );
    check(
      field('Basic salary').controller!.text == '30000',
      'Saved salary did not prefill',
    );
    check(
      field('Account number').controller!.text == '00123456789',
      'Account number lost leading zeros',
    );
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final picture = await boundary.toImage();
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${directory.path}/${sample.width.toInt()}-${sample.scale}.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
    field('Basic salary').controller!.text = '-1';
    widgets<FilledButton>().single.onPressed!();
    await frame();
    check(submits == 0, 'Negative salary submitted');
    field('Basic salary').controller!.text = '35000';
    widgets<FilledButton>().single.onPressed!();
    await frame();
    check(submits == 1, 'Valid salary did not submit');
    check(
      widgets<AppText>().any((w) => w.data == 'Salary update was rejected'),
      'Save error is hidden',
    );
    final save = widgets<FilledButton>().single.onPressed!;
    save();
    save();
    await frame();
    check(submits == 2, 'Save submitted twice');
    check(
      saved?['basic'] == 35000.0 && saved?['account_number'] == '00123456789',
      'Saved payload incorrect',
    );
    pending.complete(null);
    await result;
    await frame();
    check(
      widgets<SalaryStructureSheet>().isEmpty,
      'Successful sheet did not close',
    );
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exit(1);
  }
  stdout.writeln(
    'PASS: bottom sheet, prefilled values, validation, retry, duplicate-save protection, phone/tablet/dark/large text/keyboard layouts. Previews: ${directory.path}',
  );
  exit(0);
}
