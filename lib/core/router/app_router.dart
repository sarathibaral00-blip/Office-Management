import '../widgets/app_sidebar.dart';
import '../error/result.dart';
import 'package:hr_management/core/localization/app_text.dart';
import '../../features/preferences/presentation/bloc/preferences_cubit.dart';
import '../../features/preferences/presentation/pages/preferences_page.dart';
import '../../features/settings/presentation/bloc/settings_cubit.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/exports/presentation/bloc/exports_cubit.dart';
import '../../features/exports/presentation/pages/exports_page.dart';
import '../../features/letters/presentation/bloc/letters_cubit.dart';
import '../../features/letters/presentation/pages/letters_page.dart';
import '../../features/documents/presentation/bloc/documents_cubit.dart';
import '../../features/documents/presentation/pages/documents_page.dart';
import '../../features/expenses/presentation/bloc/expenses_cubit.dart';
import '../../features/expenses/presentation/pages/expenses_page.dart';
import '../../features/financing/presentation/bloc/financing_cubit.dart';
import '../../features/financing/presentation/pages/financing_page.dart';
import '../../features/payroll/presentation/bloc/payroll_cubit.dart';
import '../../features/payroll/presentation/pages/payroll_page.dart';
import '../../features/workspace/presentation/pages/workspace_page.dart';
import '../../features/notifications/domain/entities/notifications.dart';
import '../presentation/flow_state.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/attendance_reports/presentation/bloc/attendance_reports_cubit.dart';
import '../../features/attendance_reports/presentation/pages/attendance_reports_page.dart';
import '../../features/dashboards/presentation/bloc/dashboards_cubit.dart';
import '../../features/dashboards/presentation/pages/dashboards_page.dart';
import '../../features/notifications/presentation/bloc/notifications_cubit.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/notices/presentation/bloc/notices_cubit.dart';
import '../../features/notices/presentation/pages/notices_page.dart';
import '../../features/corrections/presentation/bloc/corrections_cubit.dart';
import '../../features/corrections/presentation/pages/corrections_page.dart';
import '../../features/holidays/presentation/bloc/holidays_cubit.dart';
import '../../features/holidays/presentation/pages/holidays_page.dart';
import '../../features/leave/presentation/bloc/leave_cubit.dart';
import '../../features/leave/presentation/pages/leave_page.dart';
import '../../features/employees/presentation/bloc/employees_cubit.dart';
import '../../features/employees/presentation/pages/employees_page.dart';
import '../../features/attendance_support/domain/entities/fallback.dart';
import '../../features/attendance_support/presentation/bloc/support_cubit.dart';
import '../../features/attendance_support/presentation/pages/support_hub_page.dart';
import '../../features/attendance_support/presentation/pages/manual_page.dart';
import '../../features/attendance_support/presentation/pages/devices_page.dart';
import '../../features/attendance_support/presentation/pages/report_page.dart';
import '../../features/attendance_support/presentation/pages/kiosk_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../di/injection.dart';
import '../widgets/app_dialog.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/pages/auth_pages.dart';
import '../../features/attendance/presentation/bloc/attendance_cubit.dart';
import '../../features/attendance/presentation/pages/home_page.dart';
import '../../features/attendance/presentation/pages/history_page.dart';
import '../../features/networks/presentation/bloc/network_cubit.dart';
import '../../features/networks/presentation/pages/networks_page.dart';

class AuthRefresh extends ChangeNotifier {
  AuthRefresh(AuthCubit auth) {
    var previous = _routingState(auth.state);
    subscription = auth.stream.listen((state) {
      final next = _routingState(state);
      if (next != previous) {
        previous = next;
        notifyListeners();
      }
    });
  }
  // Profile-only refreshes must not rebuild Navigator overlays during saves.
  static Object _routingState(AuthState state) => (
    state.status == LoadStatus.initial,
    state.employee?.id,
    state.employee?.role,
    state.employee?.active,
    state.recovering,
  );
  late final StreamSubscription<AuthState> subscription;
  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter(AuthCubit auth) => GoRouter(
  initialLocation: '/splash',
  refreshListenable: AuthRefresh(auth),
  redirect: (context, state) {
    final path = state.uri.path;
    if (auth.state.status == LoadStatus.initial) {
      return path == '/splash' ? null : '/splash';
    }
    final user = auth.state.employee;
    final public = [
      '/login',
      '/forgot-password',
      '/reset-password',
      '/kiosk',
    ].contains(path);
    if (user == null) return public ? null : '/login';
    if (auth.state.recovering) {
      return path == '/reset-password' ? null : '/reset-password';
    }
    if (path == '/reset-password') {
      return null;
    }
    if (public || path == '/splash') return '/home';
    if ([
          '/employees',
          '/attendance-reports',
          '/letters',
          '/settings',
          '/networks',
          '/attendance-support',
          '/manual-attendance',
          '/kiosk-devices',
          '/temporary-devices',
          '/non-app-report',
        ].contains(path) &&
        !user.isAdmin) {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(
      path: '/forgot-password',
      builder: (_, _) => BlocProvider(
        create: (_) => di<PasswordCubit>(),
        child: const PasswordPage(),
      ),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (_, _) => BlocProvider(
        create: (_) => di<PasswordCubit>(),
        child: const PasswordPage(update: true),
      ),
    ),
    GoRoute(
      path: '/kiosk',
      builder: (_, _) => BlocProvider(
        create: (_) => di<KioskCubit>(),
        child: const KioskPage(),
      ),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(path: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/preferences',
          builder: (_, _) => BlocProvider.value(
            value: di<PreferencesCubit>(),
            child: const PreferencesPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => BlocProvider(
            create: (_) => di<SettingsCubit>(),
            child: const SettingsPage(),
          ),
        ),
        GoRoute(
          path: '/exports',
          builder: (_, _) => BlocProvider(
            create: (_) => di<ExportsCubit>(),
            child: const ExportsPage(),
          ),
        ),
        GoRoute(
          path: '/letters',
          builder: (_, _) => BlocProvider(
            create: (_) => di<LettersCubit>(),
            child: const LettersPage(),
          ),
        ),
        GoRoute(
          path: '/documents',
          builder: (_, _) => BlocProvider(
            create: (_) => di<DocumentsCubit>(),
            child: const DocumentsPage(),
          ),
        ),
        GoRoute(
          path: '/expenses',
          builder: (_, _) => BlocProvider(
            create: (_) => di<ExpensesCubit>(),
            child: const ExpensesPage(),
          ),
        ),
        GoRoute(
          path: '/financing',
          builder: (_, _) => BlocProvider(
            create: (_) => di<FinancingCubit>(),
            child: const FinancingPage(),
          ),
        ),
        GoRoute(
          path: '/payroll',
          builder: (_, _) => BlocProvider(
            create: (_) => di<PayrollCubit>(),
            child: const PayrollPage(),
          ),
        ),
        GoRoute(path: '/workspace', builder: (_, _) => const WorkspacePage()),
        GoRoute(
          path: '/profile',
          builder: (_, _) => BlocProvider(
            create: (_) => di<ProfileCubit>(),
            child: const ProfilePage(),
          ),
        ),
        GoRoute(
          path: '/attendance-reports',
          builder: (_, _) => BlocProvider(
            create: (_) => di<AttendanceReportsCubit>(),
            child: const AttendanceReportsPage(),
          ),
        ),
        GoRoute(
          path: '/dashboards',
          builder: (_, _) => BlocProvider(
            create: (_) => di<DashboardsCubit>(),
            child: const DashboardsPage(),
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => BlocProvider(
            create: (_) => di<NotificationsCubit>(),
            child: const NotificationsPage(),
          ),
        ),
        GoRoute(
          path: '/notices',
          builder: (_, _) => BlocProvider(
            create: (_) => di<NoticesCubit>(),
            child: const NoticesPage(),
          ),
        ),
        GoRoute(
          path: '/corrections',
          builder: (_, _) => BlocProvider(
            create: (_) => di<CorrectionsCubit>(),
            child: const CorrectionsPage(),
          ),
        ),
        GoRoute(
          path: '/holidays',
          builder: (_, _) => BlocProvider(
            create: (_) => di<HolidaysCubit>(),
            child: const HolidaysPage(),
          ),
        ),
        GoRoute(
          path: '/leave',
          builder: (_, _) => BlocProvider(
            create: (_) => di<LeaveCubit>(),
            child: const LeavePage(),
          ),
        ),
        GoRoute(
          path: '/employees',
          builder: (_, _) => BlocProvider(
            create: (_) => di<EmployeesCubit>(),
            child: const EmployeesPage(),
          ),
        ),
        GoRoute(
          path: '/attendance-support',
          builder: (_, _) => BlocProvider(
            create: (_) => di<SupportCubit>()..load(),
            child: const SupportHubPage(),
          ),
        ),
        GoRoute(
          path: '/manual-attendance',
          builder: (_, state) => BlocProvider(
            create: (_) => di<ManualCubit>(),
            child: ManualPage(
              initial: state.extra is SupportRecord
                  ? state.extra as SupportRecord
                  : null,
            ),
          ),
        ),
        GoRoute(
          path: '/kiosk-devices',
          builder: (_, _) => BlocProvider(
            create: (_) => di<DevicesCubit>(),
            child: const DevicesPage(kind: 'kiosk'),
          ),
        ),
        GoRoute(
          path: '/temporary-devices',
          builder: (_, _) => BlocProvider(
            create: (_) => di<DevicesCubit>(),
            child: const DevicesPage(kind: 'temporary'),
          ),
        ),
        GoRoute(
          path: '/non-app-report',
          builder: (_, _) => BlocProvider(
            create: (_) => di<ReportCubit>(),
            child: const NonAppReportPage(),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => BlocProvider(
            create: (_) => di<HomeCubit>(),
            child: const HomePage(),
          ),
        ),
        GoRoute(
          path: '/history',
          builder: (_, _) => BlocProvider(
            create: (_) => di<HistoryCubit>(),
            child: const HistoryPage(),
          ),
        ),
        GoRoute(
          path: '/networks',
          builder: (_, _) => BlocProvider(
            create: (_) => di<NetworkCubit>(),
            child: const NetworksPage(),
          ),
        ),
      ],
    ),
  ],
);

Future<void> _confirmSignOut(BuildContext context) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.logout_rounded, size: 30.r, color: colors.primary),
        title: const AppText('Sign out?'),
        content: const AppText('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => dismissAppDialog(dialogContext, false),
            child: const AppText('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => dismissAppDialog(dialogContext, true),
            icon: Icon(Icons.logout_rounded, size: 18.r),
            label: const AppText('Yes, sign out'),
          ),
        ],
      );
    },
  );
  if (confirmed == true && context.mounted) {
    await context.read<AuthCubit>().logout();
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.employee;
    // Auth updates and router redirects are not atomic: the shell may rebuild
    // once after logout/session loss, before GoRouter removes the private route.
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final items = user.isEmployee
        ? [
            ('Today', Icons.space_dashboard_outlined, '/home'),
            ('Attendance', Icons.calendar_month_outlined, '/history'),
            ('Workspace', Icons.apps_rounded, '/workspace'),
            ('Profile', Icons.person_outline, '/profile'),
          ]
        : [
            ('Today', Icons.space_dashboard_outlined, '/home'),
            ('Dashboard', Icons.insights_outlined, '/dashboards'),
            ('Attendance', Icons.calendar_month_outlined, '/history'),
            ('Leave & approvals', Icons.beach_access_outlined, '/leave'),
            ('Workspace', Icons.apps_rounded, '/workspace'),
            if (user.isAdmin)
              ('Employees', Icons.groups_outlined, '/employees'),
            if (user.isAdmin)
              ('Reports', Icons.summarize_outlined, '/attendance-reports'),
            if (user.isAdmin)
              (
                'Attendance support',
                Icons.support_agent_rounded,
                '/attendance-support',
              ),
            if (user.isAdmin)
              ('Office networks', Icons.wifi_rounded, '/networks'),
            ('Profile', Icons.person_outline, '/profile'),
          ];
    final navItems = user.isEmployee
        ? [
            ('Today', Icons.home_rounded, '/home'),
            ('Attendance', Icons.calendar_month_rounded, '/history'),
            ('Leave', Icons.beach_access_rounded, '/leave'),
            ('Workspace', Icons.grid_view_rounded, '/workspace'),
            ('Profile', Icons.person_rounded, '/profile'),
          ]
        : user.isAdmin
        ? [
            ('Dashboard', Icons.dashboard_rounded, '/dashboards'),
            ('Attendance', Icons.calendar_month_rounded, '/history'),
            ('Approvals', Icons.fact_check_rounded, '/leave'),
            ('Employees', Icons.groups_rounded, '/employees'),
            ('Workspace', Icons.grid_view_rounded, '/workspace'),
          ]
        : [
            ('Dashboard', Icons.dashboard_rounded, '/dashboards'),
            ('Attendance', Icons.calendar_month_rounded, '/history'),
            ('Approvals', Icons.fact_check_rounded, '/leave'),
            ('Workspace', Icons.grid_view_rounded, '/workspace'),
            ('Profile', Icons.person_rounded, '/profile'),
          ];
    final current = navItems.indexWhere((i) => i.$3 == path);
    final selected = current >= 0
        ? current
        : navItems.indexWhere((i) => i.$3 == '/workspace');
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final dashboard = path == '/home' || path == '/dashboards';
    Widget menu(BuildContext menuContext, {bool drawer = false}) => AppSidebar(
      name: user.name,
      role: user.role,
      employeeCode: user.code,
      items: items,
      currentPath: path,
      onClose: drawer ? () => Navigator.of(menuContext).pop() : null,
      onNavigate: (destination) {
        if (drawer) Navigator.of(menuContext).pop();
        if (destination != path) context.go(destination);
      },
      onSignOut: () => _confirmSignOut(menuContext),
    );
    Widget drawerMenu() => Drawer(
      width: (MediaQuery.sizeOf(context).width - 24.w).clamp(0.0, 292.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24.r)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Builder(builder: (context) => menu(context, drawer: true)),
    );

    if (dashboard) {
      // Dashboard owns its status-bar/header area; no AppBar or top SafeArea.
      return Scaffold(
        drawer: drawerMenu(),
        body: SafeArea(top: false, child: child),
        bottomNavigationBar: _CompactBottomNavigation(
          items: navItems,
          selectedIndex: selected < 0 ? 0 : selected,
          onSelected: (i) => context.go(navItems[i].$3),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Pride People'),
        actions: [
          IconButton(
            tooltip: 'Display preferences',
            onPressed: () => context.push('/preferences'),
            icon: Icon(Icons.translate_rounded, size: 22.r),
          ),
          BlocProvider(
            create: (_) => di<NotificationsCubit>()..load(),
            child: BlocBuilder<NotificationsCubit, FlowState<InboxData>>(
              builder: (context, state) {
                final unread = state.data?.unread ?? 0;
                return Badge(
                  isLabelVisible: unread > 0,
                  label: AppText(
                    unread > 99 ? '99+' : '$unread',
                    style: TextStyle(fontSize: 10.sp),
                  ),
                  child: IconButton(
                    tooltip: 'Notifications',
                    icon: Icon(Icons.notifications_outlined, size: 22.r),
                    onPressed: () async {
                      await context.push('/notifications');
                      if (context.mounted) {
                        context.read<NotificationsCubit>().load();
                      }
                    },
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context),
            icon: Icon(Icons.logout_rounded, size: 22.r),
          ),
        ],
      ),
      drawer: !user.isEmployee && !wide ? drawerMenu() : null,
      body: SafeArea(
        child: wide && !user.isEmployee
            ? Row(
                children: [
                  SizedBox(width: 256.w, child: menu(context)),
                  VerticalDivider(width: 1.w),
                  Expanded(child: child),
                ],
              )
            : child,
      ),
      bottomNavigationBar: _CompactBottomNavigation(
        items: navItems,
        selectedIndex: selected < 0 ? 0 : selected,
        onSelected: (i) => context.go(navItems[i].$3),
      ),
    );
  }
}

class _CompactBottomNavigation extends StatelessWidget {
  const _CompactBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(String, IconData, String)> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(12.w, 0, 12.w, 7.h),
      child: Container(
        height: 64.h,
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: dark ? colors.surfaceContainerHigh : colors.surface,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .45),
            width: 1.w,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .07),
              blurRadius: 18.r,
              offset: Offset(0, 5.h),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == selectedIndex;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: translate(context, item.$1),
                child: Tooltip(
                  message: translate(context, item.$1),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17.r),
                      onTap: () => onSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primary.withValues(alpha: .11)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(17.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 5.h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected ? item.$2 : _outlinedIcon(item.$2),
                              size: 21.r,
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                            SizedBox(height: 2.h),
                            AppText(
                              item.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                height: 1.15,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  IconData _outlinedIcon(IconData icon) => switch (icon) {
    Icons.home_rounded => Icons.home_outlined,
    Icons.calendar_month_rounded => Icons.calendar_month_outlined,
    Icons.beach_access_rounded => Icons.beach_access_outlined,
    Icons.grid_view_rounded => Icons.grid_view_outlined,
    Icons.person_rounded => Icons.person_outline_rounded,
    Icons.dashboard_rounded => Icons.dashboard_outlined,
    Icons.fact_check_rounded => Icons.fact_check_outlined,
    Icons.groups_rounded => Icons.groups_outlined,
    _ => icon,
  };
}
