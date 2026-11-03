import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/core/widgets/app_widgets.dart';

void main() {
  for (final width in [320.0, 430.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Compact tiles at width $width and text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            enableScaleWH: () => width < 600,
            builder: (_, _) => MaterialApp(
              theme: ThemeData(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: width == 1024 ? ThemeMode.dark : ThemeMode.light,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1000),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: CompactPageBody(
                    child: Column(
                      children: [
                        const PageHeading(title: 'Leave & approvals'),
                        ResponsiveTiles(
                          children: const [
                            AppCard(
                              key: ValueKey('first'),
                              child: Text('Annual leave'),
                            ),
                            AppCard(
                              key: ValueKey('second'),
                              child: Text(
                                'Compensatory leave\n12 remaining\n4 used / 16 days',
                              ),
                            ),
                            AppCard(child: Text('Unpaid leave')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final first = tester.getRect(find.byKey(const ValueKey('first')));
        final second = tester.getRect(find.byKey(const ValueKey('second')));
        expect(first.width, second.width);
        if (scale == 1) {
          expect(first.top, second.top);
          expect(first.height, second.height);
        } else {
          expect(second.top, greaterThan(first.bottom));
        }
      });
    }
  }
}
