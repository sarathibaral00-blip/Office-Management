import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/dashboard_card.dart';
import 'package:go_router/go_router.dart';
import '../../../dashboards/presentation/widgets/dashboard_actions.dart';
import '../../../weather/presentation/widgets/weather_badge.dart';
import '../../../../core/widgets/dashboard_layout.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/attendance.dart';
import '../bloc/attendance_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Timer? timer;
  DateTime now = DateTime.now();
  bool confirmingCheckout = false;

  Future<void> submitAttendance(Attendance? open) async {
    final cubit = context.read<HomeCubit>();
    if (cubit.state.busy || confirmingCheckout) return;
    if (open == null) {
      await cubit.punch('check_in');
      return;
    }
    confirmingCheckout = true;
    try {
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final colors = Theme.of(dialogContext).colorScheme;
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: 24.w,
              vertical: 24.h,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 380.w),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        size: 36.r,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    AppText(
                      'Ready to check out?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    AppText(
                      'Are you sure you want to check out? Your checkout time will be recorded when you confirm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    AppButton(
                      label: 'Yes, check out',
                      icon: Icons.logout_rounded,
                      onPressed: () => dismissAppDialog(dialogContext, true),
                    ),
                    SizedBox(height: 10.h),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => dismissAppDialog(dialogContext, false),
                        child: const AppText('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (!mounted || cubit.isClosed || confirmed != true) return;
      // A refresh while the dialog was open must not check out a different row.
      final latest = cubit.state.month?.open;
      if (latest == null ||
          latest.day != open.day ||
          latest.checkIn != open.checkIn) {
        return;
      }
      await cubit.punch('check_out');
    } finally {
      confirmingCheckout = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
    context.read<HomeCubit>().load().then((_) {
      if (mounted) context.read<HomeCubit>().verify();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<HomeCubit>().load();
      context.read<HomeCubit>().verify();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<HomeCubit, AttendanceState>(
    listener: (context, state) {
      if (state.status == LoadStatus.failure && state.message != null) {
        toast(context, state.message!);
      }
    },
    builder: (context, state) {
      final user = context.watch<AuthCubit>().state.employee;
      final month = state.month;
      final records = month?.records ?? <Attendance>[];
      final today = month?.today ?? now;
      final matches = records.where(
        (a) => WorkMonth.key(a.day) == WorkMonth.key(today),
      );
      final a = matches.isEmpty ? null : matches.first;
      final open = month?.open;
      final active = open ?? a;
      final hours = active?.hours(now) ?? Duration.zero;
      return RefreshIndicator(
        onRefresh: () async {
          await context.read<HomeCubit>().load();
          if (context.mounted) await context.read<HomeCubit>().verify();
        },
        child: DashboardLayout(
          trailing: const WeatherBadge(onHeader: true),
          title: user?.name ?? 'My workspace',
          topBar: const DashboardActions(),
          greetingTime: now,
          onTitleTap: () => context.push('/profile'),
          subtitle: DateFormat('EEEE, MMMM d').format(now),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: AppText(
                  'Make today a great day.',
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 6.h),
              SizedBox(height: 14.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF800020),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          color: Colors.white,
                          size: 22.r,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: AppText(
                            'Your workday',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (user?.code.isNotEmpty == true) ...[
                          SizedBox(width: 8.w),
                          Flexible(
                            child: AppText(
                              'Employee ID: ${user!.code}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 14.h),
                    AppText(
                      DateFormat('hh:mm:ss').format(now),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.sp,
                      ),
                    ),
                    AppText(
                      '${DateFormat('a').format(now)} · device local time',
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                    SizedBox(height: 12.h),
                    StatusBadge(
                      label: state.allowed == null
                          ? 'Verify office network'
                          : state.allowed!
                          ? 'Office network verified'
                          : 'Connect to office WiFi',
                      color: state.allowed == true
                          ? const Color(0xFF9BE4B0)
                          : const Color(0xFFFFD39A),
                      icon: Icons.wifi_rounded,
                    ),
                    SizedBox(height: 14.h),
                    FilledButtonTheme(
                      data: FilledButtonThemeData(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF800020),
                          disabledBackgroundColor: Colors.white24,
                          disabledForegroundColor: Colors.white70,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          textStyle: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                      child: AppButton(
                        label: active?.checkOut != null
                            ? 'Workday complete'
                            : open != null
                            ? 'Check out'
                            : 'Check in',
                        icon: open != null
                            ? Icons.logout_rounded
                            : Icons.login_rounded,
                        loading: state.busy,
                        onPressed:
                            state.month == null || active?.checkOut != null
                            ? null
                            : () => submitAttendance(open),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              if (state.status == LoadStatus.loading && month == null)
                const Loader()
              else if (month == null)
                EmptyState(
                  title: 'Workspace unavailable',
                  message: state.message ?? 'Pull down to retry.',
                  onRetry: () => context.read<HomeCubit>().load(),
                )
              else
                DashboardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              'Today at a glance',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: StatusBadge(
                                label: active == null
                                    ? 'Ready when you are'
                                    : active.status == 'late'
                                    ? 'Late arrival'
                                    : active.checkOut == null
                                    ? 'On the clock'
                                    : 'Completed',
                                color: active?.status == 'late'
                                    ? const Color(0xFFED9B00)
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              'Hours worked',
                              '${hours.inHours}h ${hours.inMinutes.remainder(60)}m',
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              'Checked in',
                              active == null
                                  ? '—'
                                  : DateFormat(
                                      'hh:mm a',
                                    ).format(active.checkIn.toLocal()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 12.h),
              DashboardCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.wifi_tethering_rounded,
                      size: 24.r,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'A seamless start',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          const AppText(
                            'Connect to office WiFi before checking in or out. Contact HR if your office network has changed.',
                          ),
                          TextButton(
                            onPressed: () => context.read<HomeCubit>().verify(),
                            child: const AppText('Refresh network status'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        label,
        style: TextStyle(
          fontSize: 12.sp,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      SizedBox(height: 6.h),
      AppText(
        value,
        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
      ),
    ],
  );
}
