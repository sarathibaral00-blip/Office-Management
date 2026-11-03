// Standalone sidebar previews with synthetic identity data; no network or Auth.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr_management/core/widgets/app_sidebar.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  final directory = Directory('/tmp/hr-sidebar-preview');
  await directory.create(recursive: true);
  for (final sample in [
    (width: 390.0, height: 844.0, scale: 1.0, dark: false),
    (width: 320.0, height: 640.0, scale: 2.0, dark: false),
    (width: 1024.0, height: 768.0, scale: 1.0, dark: true),
  ]) {
    final capture = GlobalKey();
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
                            brightness: sample.dark
                                ? Brightness.dark
                                : Brightness.light,
                          ),
                        ),
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: Size(sample.width, sample.height),
                            textScaler: TextScaler.linear(sample.scale),
                          ),
                          child: child!,
                        ),
                        home: Scaffold(
                          backgroundColor: const Color(0xFFEDE6E8),
                          body: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: sample.width >= 600 ? 256.w : 292.w,
                              child: AppSidebar(
                                name: 'Amina Rahman',
                                role: 'super_admin',
                                employeeCode: 'EMP-0042',
                                currentPath: '/leave',
                                items: const [
                                  (
                                    'Today',
                                    Icons.space_dashboard_outlined,
                                    '/home',
                                  ),
                                  (
                                    'Dashboard',
                                    Icons.insights_outlined,
                                    '/dashboards',
                                  ),
                                  (
                                    'Attendance',
                                    Icons.calendar_month_outlined,
                                    '/history',
                                  ),
                                  (
                                    'Leave & approvals',
                                    Icons.beach_access_outlined,
                                    '/leave',
                                  ),
                                  (
                                    'Workspace',
                                    Icons.apps_rounded,
                                    '/workspace',
                                  ),
                                  (
                                    'Employees',
                                    Icons.groups_outlined,
                                    '/employees',
                                  ),
                                  (
                                    'Reports',
                                    Icons.summarize_outlined,
                                    '/attendance-reports',
                                  ),
                                  (
                                    'Attendance support',
                                    Icons.support_agent_rounded,
                                    '/attendance-support',
                                  ),
                                  (
                                    'Office networks',
                                    Icons.wifi_rounded,
                                    '/networks',
                                  ),
                                  ('Profile', Icons.person_outline, '/profile'),
                                ],
                                onClose: sample.width < 600 ? () {} : null,
                                onNavigate: (_) {},
                                onSignOut: () {},
                              ),
                            ),
                          ),
                        ),
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
    await Future<void>.delayed(const Duration(milliseconds: 400));
    binding.scheduleFrame();
    await binding.endOfFrame;
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${directory.path}/${sample.width.toInt()}.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exit(1);
  }
  stdout.writeln(
    'PASS: phone, small phone with 2x text, desktop dark mode. Previews: ${directory.path}',
  );
  exit(0);
}
