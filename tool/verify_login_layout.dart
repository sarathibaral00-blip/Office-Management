// Runs the real LoginPage with fake Auth responses; no Supabase or live sign-ins.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hr_management/core/constants/app_assets.dart';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:hr_management/core/widgets/app_widgets.dart';
import 'package:hr_management/features/auth/domain/entities/employee.dart';
import 'package:hr_management/features/auth/domain/usecases/auth_actions.dart';
import 'package:hr_management/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:hr_management/features/auth/presentation/pages/auth_pages.dart';
import 'package:hr_management/features/auth/presentation/widgets/login_layout.dart';
import '../test/support/scenarios.dart' show FakeAuth;

class _Auth extends FakeAuth {
  int calls = 0;
  String? submittedEmail;
  final pending = Completer<Result<Employee?>>();
  @override
  Future<Result<Employee?>> login(String email, String password) {
    calls++;
    submittedEmail = email;
    return pending.future;
  }
}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  Future<void> frame() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    binding.scheduleFrame();
    await binding.endOfFrame;
  }

  void check(bool value, String message) {
    if (!value) throw StateError(message);
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

  final directory = Directory('/tmp/hr-login-preview');
  await directory.create(recursive: true);
  for (final sample in [
    (
      width: 360.0,
      height: 640.0,
      keyboard: 0.0,
      scale: 1.0,
      dark: false,
      top: 24.0,
      bottom: 24.0,
      side: 0.0,
    ),
    (
      width: 430.0,
      height: 932.0,
      keyboard: 0.0,
      scale: 1.0,
      dark: false,
      top: 59.0,
      bottom: 34.0,
      side: 0.0,
    ),
    (
      width: 360.0,
      height: 800.0,
      keyboard: 0.0,
      scale: 1.0,
      dark: false,
      top: 32.0,
      bottom: 24.0,
      side: 0.0,
    ),
    (
      width: 1024.0,
      height: 1366.0,
      keyboard: 0.0,
      scale: 1.0,
      dark: false,
      top: 24.0,
      bottom: 20.0,
      side: 0.0,
    ),
    (
      width: 1024.0,
      height: 768.0,
      keyboard: 0.0,
      scale: 1.0,
      dark: false,
      top: 0.0,
      bottom: 20.0,
      side: 44.0,
    ),
    (
      width: 360.0,
      height: 640.0,
      keyboard: 280.0,
      scale: 1.0,
      dark: false,
      top: 24.0,
      bottom: 0.0,
      side: 0.0,
    ),
    (
      width: 430.0,
      height: 932.0,
      keyboard: 310.0,
      scale: 1.0,
      dark: false,
      top: 59.0,
      bottom: 0.0,
      side: 0.0,
    ),
    (
      width: 390.0,
      height: 844.0,
      keyboard: 0.0,
      scale: 1.0,
      dark: true,
      top: 47.0,
      bottom: 34.0,
      side: 0.0,
    ),
    (
      width: 360.0,
      height: 640.0,
      keyboard: 280.0,
      scale: 2.0,
      dark: true,
      top: 24.0,
      bottom: 0.0,
      side: 0.0,
    ),
  ]) {
    final repository = _Auth();
    final auth = AuthCubit(AuthActions(repository));
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(
          path: '/forgot-password',
          builder: (_, _) => const Scaffold(body: Text('Password recovery')),
        ),
      ],
    );
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
                      final colors = ColorScheme.fromSeed(
                        seedColor: const Color(0xFF800020),
                        primary: sample.dark
                            ? const Color(0xFFFFB1C1)
                            : const Color(0xFF800020),
                        brightness: sample.dark
                            ? Brightness.dark
                            : Brightness.light,
                      );
                      return BlocProvider.value(
                        value: auth,
                        child: MaterialApp.router(
                          debugShowCheckedModeBanner: false,
                          theme: ThemeData(
                            useMaterial3: true,
                            colorScheme: colors,
                            inputDecorationTheme: InputDecorationTheme(
                              filled: true,
                              fillColor: colors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14.r),
                                borderSide: BorderSide(
                                  color: colors.outlineVariant,
                                ),
                              ),
                            ),
                            filledButtonTheme: FilledButtonThemeData(
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20.w,
                                  vertical: 16.h,
                                ),
                                textStyle: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              size: Size(sample.width, sample.height),
                              padding: EdgeInsets.only(
                                top: sample.top,
                                bottom: 12.h,
                              ),
                              viewInsets: EdgeInsets.only(
                                bottom: sample.keyboard,
                              ),
                              textScaler: TextScaler.linear(sample.scale),
                            ),
                            child: child!,
                          ),
                          routerConfig: router,
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
    await frame();
    await frame();
    Future<void> snapshot(String suffix) async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${directory.path}/${sample.width.toInt()}x${sample.height.toInt()}-${sample.keyboard.toInt()}-${sample.dark}-${sample.scale}-$suffix.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    final loginScaffold = widgets<Scaffold>().single;
    check(
      loginScaffold.extendBodyBehindAppBar &&
          loginScaffold.extendBody &&
          !loginScaffold.resizeToAvoidBottomInset!,
      'Login scaffold is not full-window',
    );
    check(
      loginScaffold.backgroundColor == LoginLayout.topColor,
      'Login fallback is not maroon',
    );
    final overlay = widgets<AnnotatedRegion<SystemUiOverlayStyle>>().last.value;
    check(
      overlay.statusBarColor == Colors.transparent &&
          overlay.statusBarIconBrightness == Brightness.light,
      'Login system bar styling is incorrect',
    );
    Element? topImage;
    void findTop(Element element) {
      if (element.widget case Image(
        image: AssetImage(assetName: final asset),
      ) when asset == AppAssets.loginTopBanner) {
        topImage = element;
      }
      element.visitChildren(findTop);
    }

    findTop(binding.rootElement!);
    final rootBox = capture.currentContext!.findRenderObject()! as RenderBox;
    final bannerBox = topImage!.findRenderObject()! as RenderBox;
    final origin = bannerBox.localToGlobal(Offset.zero, ancestor: rootBox);
    check(
      origin.dy.abs() < .01 && origin.dx.abs() < .01,
      'Top banner does not start at x=0/y=0: $origin',
    );
    check(
      (bannerBox.size.width - sample.width).abs() < .01,
      'Top banner does not fill screen width',
    );
    await snapshot('initial');
    final hasBottom = widgets<Image>().any(
      (w) =>
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == AppAssets.loginBottomBanner,
    );
    check(
      hasBottom == (!sample.dark && sample.keyboard == 0),
      'Cartoon visibility is incorrect',
    );
    final mail = widgets<AppTextField>().singleWhere(
      (w) => w.label == 'Work email',
    );
    final password = widgets<AppTextField>().singleWhere(
      (w) => w.label == 'Password',
    );
    check(
      mail.textInputAction == TextInputAction.next &&
          password.textInputAction == TextInputAction.done,
      'Keyboard actions missing',
    );
    widgets<AppButton>().single.onPressed!();
    await frame();
    check(repository.calls == 0, 'Empty login submitted');
    mail.controller.text = 'invalid';
    password.controller.text = 'fixture-password';
    widgets<AppButton>().single.onPressed!();
    await frame();
    check(repository.calls == 0, 'Invalid email submitted');
    widgets<IconButton>()
        .singleWhere((w) => w.tooltip == 'Show password')
        .onPressed!();
    await frame();
    check(
      !widgets<AppTextField>()
          .singleWhere((w) => w.label == 'Password')
          .obscure,
      'Password toggle failed',
    );
    mail.controller.text = '  amina@example.invalid  ';
    password.onFieldSubmitted!('fixture-password');
    await frame();
    check(
      repository.calls == 1 &&
          repository.submittedEmail == 'amina@example.invalid',
      'Keyboard submit changed login data',
    );
    check(
      widgets<FilledButton>().single.onPressed == null,
      'Loading login remains enabled',
    );
    password.onFieldSubmitted!('fixture-password');
    check(repository.calls == 1, 'Loading submission repeated');
    repository.pending.complete(
      const Result.failure(
        Failure('Unable to sign in. Check your email and password.'),
      ),
    );
    await frame();
    check(
      widgets<AppText>().any(
        (w) => w.data == 'Unable to sign in. Check your email and password.',
      ),
      'Existing Bloc error missing',
    );
    check(
      !widgets<AppButton>().single.loading,
      'Failure did not restore submit',
    );
    // Scroll the actual form so its last control is reachable with the keyboard.
    final loginButtonContext = <BuildContext>[];
    void findButton(Element element) {
      if (element.widget is AppButton) loginButtonContext.add(element);
      element.visitChildren(findButton);
    }

    findButton(binding.rootElement!);
    await Scrollable.ensureVisible(loginButtonContext.single, alignment: 1);
    await frame();
    await snapshot('failure');
    widgets<TextButton>().single.onPressed!();
    await frame();
    check(
      router.routeInformationProvider.value.uri.path == '/forgot-password',
      'Existing forgot-password route changed',
    );
    runApp(const SizedBox.shrink());
    await frame();
    router.dispose();
    await auth.close();
    await repository.events.close();
  }
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exit(1);
  }
  stdout.writeln(
    'PASS: banner at x=0/y=0 and full width, full-window scaffold, notch/punch-hole/20:9/tablet/landscape/keyboard/dark/2x text; assets, validation, password toggle, keyboard submit, loading, existing Bloc errors and forgot route. Screenshots: ${directory.path}',
  );
  exit(0);
}
