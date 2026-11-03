import 'package:hr_management/core/widgets/dashboard_card.dart';
// Standalone Flutter-engine smoke check; synthetic weather, no network/Auth.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr_management/core/di/injection.dart';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/core/widgets/dashboard_layout.dart';
import 'package:hr_management/features/weather/domain/entities/weather.dart';
import 'package:hr_management/features/weather/domain/repositories/weather_repository.dart';
import 'package:hr_management/features/weather/domain/usecases/get_weather.dart';
import 'package:hr_management/features/weather/presentation/bloc/weather_cubit.dart';
import 'package:hr_management/features/weather/presentation/widgets/weather_badge.dart';

class _Weather implements WeatherRepository {
  @override
  Future<Result<Weather>> current() async => Result.success(
    Weather(
      city: 'Dhaka',
      celsius: 28,
      code: 2,
      isDay: true,
      observedAt: DateTime.now().toUtc(),
    ),
  );
}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
  };
  di.registerFactory(() => WeatherCubit(GetWeather(_Weather())));
  final directory = Directory('/tmp/hr-dashboard-verification');
  await directory.create(recursive: true);
  for (final testCase in [
    (width: 320.0, height: 740.0, scale: 1.0, dark: false),
    (width: 390.0, height: 844.0, scale: 2.0, dark: false),
    (width: 1024.0, height: 768.0, scale: 1.0, dark: true),
  ]) {
    final capture = GlobalKey();
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: OverflowBox(
            maxWidth: testCase.width,
            maxHeight: testCase.height,
            child: SizedBox(
              width: testCase.width,
              height: testCase.height,
              child: RepaintBoundary(
                key: capture,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(testCase.width, testCase.height),
                    textScaler: TextScaler.linear(testCase.scale),
                  ),
                  child: ScreenUtilInit(
                    key: UniqueKey(),
                    designSize: const Size(390, 844),
                    enableScaleWH: () => testCase.width < 600,
                    fontSizeResolver: (size, util) =>
                        size * util.scaleWidth.clamp(.85, 1.2),
                    builder: (_, _) {
                      ScreenUtil.configure(
                        data: MediaQueryData(
                          size: Size(testCase.width, testCase.height),
                        ),
                        designSize: const Size(390, 844),
                      );
                      return MaterialApp(
                        debugShowCheckedModeBanner: false,
                        theme: ThemeData(
                          useMaterial3: true,
                          colorScheme: ColorScheme.fromSeed(
                            seedColor: const Color(0xFF800020),
                            brightness: testCase.dark
                                ? Brightness.dark
                                : Brightness.light,
                          ),
                        ),
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: Size(testCase.width, testCase.height),
                            padding: const EdgeInsets.only(top: 44),
                            textScaler: TextScaler.linear(testCase.scale),
                          ),
                          child: child!,
                        ),
                        home: Scaffold(
                          body: DashboardLayout(
                            title: 'Amina Rahman',
                            greetingTime: DateTime(2026, 10, 28, 11),
                            topBar: Row(
                              children: [
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.translate,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: 'Wednesday, October 28',
                            trailing: const WeatherBadge(onHeader: true),
                            child: Column(
                              children: [
                                DashboardGrid(
                                  children: const [
                                    DashboardMetric(
                                      label: 'Headcount',
                                      value: '124',
                                      icon: Icons.groups_outlined,
                                      color: Color(0xFF800020),
                                    ),
                                    DashboardMetric(
                                      label: 'Present today',
                                      value: '112',
                                      icon: Icons.check_circle_outline,
                                      color: Colors.green,
                                    ),
                                    DashboardMetric(
                                      label: 'Pending requests',
                                      value: '8',
                                      icon: Icons.pending_actions,
                                      color: Colors.orange,
                                    ),
                                    DashboardMetric(
                                      label: 'Annual leave',
                                      value: '12.0 days',
                                      icon: Icons.event_available,
                                      color: Color(0xFF800020),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                DashboardCard(
                                  child: Text('This month’s attendance'),
                                ),
                                ...List.generate(
                                  12,
                                  (i) => Padding(
                                    padding: EdgeInsets.all(16.r),
                                    child: Text('Dashboard card ${i + 1}'),
                                  ),
                                ),
                              ],
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
    await Future<void>.delayed(const Duration(milliseconds: 350));
    binding.scheduleFrame();
    await binding.endOfFrame;
    Future<void> snapshot(String suffix) async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${directory.path}/${testCase.width.toInt()}-$suffix.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    await snapshot('expanded');
    void scroll(Element element) {
      final widget = element.widget;
      if (widget is SingleChildScrollView &&
          widget.controller?.hasClients == true) {
        widget.controller!.jumpTo(120.h);
      }
      element.visitChildElements(scroll);
    }

    binding.rootElement!.visitChildElements(scroll);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    binding.scheduleFrame();
    await binding.endOfFrame;
    await snapshot('scrolled');
  }
  if (errors.isNotEmpty) {
    for (final error in errors) {
      stderr.writeln(error);
    }
    exit(1);
  }
  stdout.writeln(
    'PASS: phone/tablet, large text, dark mode and header scrolling; screenshots in ${directory.path}',
  );
  exit(0);
}
