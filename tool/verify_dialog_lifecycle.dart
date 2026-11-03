// Standalone Flutter-engine regression checks; no network or Supabase session.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hr_management/core/error/result.dart';
import 'package:hr_management/core/router/app_router.dart';
import 'package:hr_management/core/widgets/app_dialog.dart';
import 'package:hr_management/features/auth/domain/entities/employee.dart';
import 'package:hr_management/features/auth/domain/repositories/auth_repository.dart';
import 'package:hr_management/features/auth/domain/usecases/auth_actions.dart';
import 'package:hr_management/features/auth/presentation/bloc/auth_cubit.dart';

class _Auth implements AuthRepository {
  Employee? employee = const Employee(
    id: 'fixture',
    name: 'Test Employee',
    role: 'employee',
    active: true,
  );
  final events = StreamController<AuthSessionEvent>.broadcast();
  @override
  Stream<AuthSessionEvent> get changes => events.stream;
  @override
  Future<Result<Employee?>> restore() async => Result.success(employee);
  @override
  Future<Result<Employee?>> login(String email, String password) => restore();
  @override
  Future<Result<void>> logout() async {
    employee = null;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> password(String password) async =>
      const Result.success(null);
  @override
  Future<Result<void>> reset(String email) async => const Result.success(null);
}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  Future<void> frame([int milliseconds = 300]) async {
    await Future<void>.delayed(Duration(milliseconds: milliseconds));
    binding.scheduleFrame();
    await binding.endOfFrame;
  }

  void check(bool value, String reason) {
    if (!value) throw StateError(reason);
  }

  final repo = _Auth();
  final auth = AuthCubit(AuthActions(repo));
  final refresh = AuthRefresh(auth);
  var redirects = 0;
  refresh.addListener(() => redirects++);
  await auth.restore();
  final content = GlobalKey();
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (_, state) =>
        auth.state.employee == null && state.uri.path != '/login'
        ? '/login'
        : null,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => AppShell(
          path: '/home',
          child: SizedBox(key: content, child: const Text('Protected content')),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login')),
      ),
    ],
  );
  runApp(
    BlocProvider.value(
      value: auth,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        enableScaleWH: () => false,
        builder: (_, _) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await frame();
  final initialRedirects = redirects;
  for (var i = 0; i < 4; i++) {
    final controller = TextEditingController(text: 'Review comment');
    late BuildContext dialogContext;
    var disposed = false;
    final result =
        showAppDialog<String>(
          context: content.currentContext!,
          builder: (context) {
            dialogContext = context;
            return AlertDialog(
              title: const Text('Approve request'),
              content: TextField(controller: controller),
            );
          },
        ).then((result) {
          controller.dispose();
          disposed = true;
          return result;
        });
    await frame();
    repo.employee = Employee(
      id: 'fixture',
      name: 'Updated Employee $i',
      role: 'employee',
      active: true,
    );
    await auth
        .restore(); // Saving a profile must not rebuild Navigator routing.
    check(
      redirects == initialRedirects,
      'Profile-only refresh notified routing',
    );
    if (!dialogContext.mounted) {
      throw StateError('Dialog unexpectedly unmounted');
    }
    dismissAppDialog(dialogContext, 'approved');
    dismissAppDialog(
      dialogContext,
    ); // A second callback during reverse animation is ignored.
    check(
      !disposed,
      'Controller disposed before the dialog overlay was removed',
    );
    check(await result == 'approved', 'Dialog result was lost');
    await frame();
    check(
      disposed && !dialogContext.mounted,
      'Dialog future finished before unmount',
    );
    // Intentionally pass an unmounted context to exercise the helper's guard.
    // ignore: use_build_context_synchronously
    dismissAppDialog(dialogContext);
    check(
      router.routeInformationProvider.value.uri.path == '/home',
      'Late callback popped the underlying page',
    );
  }
  // Drop the user while an overlay is open. The shell can rebuild before the
  // router redirect; it must never force-unwrap employee or build private pages.
  final controller = TextEditingController();
  final pending = showAppDialog<void>(
    context: content.currentContext!,
    builder: (_) => AlertDialog(content: TextField(controller: controller)),
  );
  await frame();
  await auth.logout();
  await frame();
  if (router.routerDelegate.navigatorKey.currentState!.canPop()) {
    router.routerDelegate.navigatorKey.currentState!.pop();
  }
  await pending;
  controller.dispose();
  await frame();
  check(
    auth.state.employee == null &&
        router.routeInformationProvider.value.uri.path == '/login',
    'Logout did not remove the private route',
  );
  // Repeat session loss with the sidebar open (the real Sign out location).
  repo.employee = const Employee(
    id: 'fixture',
    name: 'Test Employee',
    role: 'employee',
    active: true,
  );
  await auth.restore();
  router.go('/home');
  await frame();
  Scaffold.of(content.currentContext!).openDrawer();
  await frame();
  await auth.logout();
  await frame();
  // Directly mount the real shell with no user, independent of redirect timing.
  runApp(
    BlocProvider.value(
      value: auth,
      child: const MaterialApp(
        home: AppShell(
          path: '/home',
          child: Text('Private child must not build'),
        ),
      ),
    ),
  );
  await frame();
  if (errors.isNotEmpty) {
    for (final error in errors) {
      stderr.writeln(error);
    }
    exit(1);
  }
  router.dispose();
  refresh.dispose();
  await auth.close();
  await repo.events.close();
  stdout.writeln(
    'PASS: null-user shell, profile refresh during dialogs, repeated approval, overlay/controller disposal and late callbacks after dismissal',
  );
  exit(0);
}
