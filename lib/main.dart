import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/presentation/flow_state.dart';
import 'features/preferences/domain/entities/preferences.dart';
import 'features/preferences/presentation/bloc/preferences_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isEmpty || key.isEmpty) {
    runApp(const ConfigurationApp());
    return;
  }
  try {
    await Supabase.initialize(url: url, publishableKey: key);
  } catch (_) {
    runApp(const ConfigurationApp());
    return;
  }
  configureDependencies(Supabase.instance.client);
  await initializeDateFormatting('bn');
  await di<PreferencesCubit>().load();
  final auth = di<AuthCubit>();
  runApp(MyApp(auth: auth));
  await auth.restore();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.auth});
  final AuthCubit auth;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter router = createRouter(widget.auth);
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: di<PreferencesCubit>(),
    child: BlocBuilder<PreferencesCubit, FlowState<UiPreferences>>(
      builder: (context, state) {
        final pref = state.data ?? const UiPreferences();
        Intl.defaultLocale = pref.language;
        return ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          enableScaleWH: () =>
              View.of(context).physicalSize.width /
                  View.of(context).devicePixelRatio <
              600,
          fontSizeResolver: (size, util) =>
              size * util.scaleWidth.clamp(.85, 1.2),
          splitScreenMode: true,
          builder: (_, _) => BlocProvider.value(
            value: widget.auth,
            child: MaterialApp.router(
              title: 'Pride People',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.theme(Brightness.light),
              darkTheme: AppTheme.theme(Brightness.dark),
              locale: Locale(pref.language),
              supportedLocales: const [Locale('en'), Locale('bn')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              themeMode: switch (pref.theme) {
                'dark' => ThemeMode.dark,
                'light' => ThemeMode.light,
                _ => ThemeMode.system,
              },
              routerConfig: router,
            ),
          ),
        );
      },
    ),
  );
}

class ConfigurationApp extends StatelessWidget {
  const ConfigurationApp({super.key});
  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    enableScaleWH: () =>
        View.of(context).physicalSize.width /
            View.of(context).devicePixelRatio <
        600,
    fontSizeResolver: (size, util) => size * util.scaleWidth.clamp(.85, 1.2),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.theme(Brightness.light),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.r),
            child: Text(
              'Workspace setup required. Provide SUPABASE_URL and SUPABASE_ANON_KEY using --dart-define.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.sp),
            ),
          ),
        ),
      ),
    ),
  );
}
