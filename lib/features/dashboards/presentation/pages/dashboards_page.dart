import '../../../../core/widgets/dashboard_card.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../widgets/dashboard_actions.dart';
import '../../../weather/presentation/widgets/weather_badge.dart';
import '../../../../core/widgets/dashboard_layout.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../attendance/presentation/widgets/attendance_source_badge.dart';
import '../../domain/entities/dashboards.dart';
import '../bloc/dashboards_cubit.dart';

class DashboardsPage extends StatefulWidget {
  const DashboardsPage({super.key});
  @override
  State<DashboardsPage> createState() => _DashboardsPageState();
}

class _DashboardsPageState extends State<DashboardsPage> {
  Timer? clock;
  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    context.read<DashboardsCubit>().load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DashboardsCubit, FlowState<DashboardData>>(
    builder: (context, state) {
      final data = state.data;
      return DashboardLayout(
        trailing: const WeatherBadge(onHeader: true),
        title:
            context.watch<AuthCubit>().state.employee?.name ?? 'My workspace',
        subtitle: DateFormat('EEEE, MMMM d').format(DateTime.now()),
        topBar: const DashboardActions(),
        greetingTime: DateTime.now(),
        onTitleTap: () => context.push('/profile'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.read<DashboardsCubit>().load(),
              icon: Icon(Icons.refresh, size: 18.r),
              label: const AppText('Refresh overview'),
            ),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Overview unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: () => context.read<DashboardsCubit>().load(),
              )
            else ...[
              DashboardGrid(
                children: [
                  if (data.role != 'employee')
                    DashboardMetric(
                      label: 'Headcount',
                      value: '${data.headcount}',
                      icon: Icons.groups_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  DashboardMetric(
                    label: 'Present today',
                    value: '${data.present}',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF2E7D32),
                  ),
                  DashboardMetric(
                    label: 'Late today',
                    value: '${data.late}',
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFFB77912),
                  ),
                  DashboardMetric(
                    label: 'On leave',
                    value: '${data.onLeave}',
                    icon: Icons.beach_access_outlined,
                    color: const Color(0xFF5278A3),
                  ),
                  DashboardMetric(
                    label: 'Pending requests',
                    value: '${data.pending}',
                    icon: Icons.pending_actions_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  ActionChip(
                    label: AppText(
                      '${data.unreadNotices} unread notices',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    onPressed: () => context.push('/notices'),
                  ),
                  ActionChip(
                    label: AppText(
                      '${data.unreadNotifications} unread notifications',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    onPressed: () => context.push('/notifications'),
                  ),
                  ActionChip(
                    label: AppText(
                      'Review requests',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    onPressed: () => context.push('/leave'),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              DashboardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'This month’s attendance',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      height: 150.h,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28.h,
                                getTitlesWidget: (v, meta) => AppText(
                                  ['Present', 'Late', 'Absent'][v.toInt().clamp(
                                    0,
                                    2,
                                  )],
                                  style: TextStyle(fontSize: 11.sp),
                                ),
                              ),
                            ),
                          ),
                          barGroups: List.generate(
                            3,
                            (i) => BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: data.chart[i],
                                  width: 24.w,
                                  borderRadius: BorderRadius.circular(6.r),
                                  color: [
                                    Colors.green,
                                    Colors.orange,
                                    Colors.red,
                                  ][i],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    AppText(
                      'Present ${data.chart[0]} · Late ${data.chart[1]} · Absent ${data.chart[2]}',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    SizedBox(height: 8.h),
                    AppText(
                      'Absence excludes holidays, non-working days, dates before joining and approved leave. Today remains open.',
                      style: TextStyle(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              AppText(
                'My leave balances',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12.h),
              DashboardGrid(
                children: data.balances
                    .map(
                      (b) => DashboardMetric(
                        label: b.name,
                        value: b.paid ? '${b.remaining} days' : 'Unpaid',
                        icon: Icons.event_available_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                    .toList(),
              ),
              if (data.role != 'employee') ...[
                SizedBox(height: 16.h),
                AppText(
                  'Team attendance today',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12.h),
                ...data.team.map(
                  (t) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: DashboardCard(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              Icons.person_outline_rounded,
                              size: 20.r,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  t.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 3.h),
                                AppText(
                                  '${t.code} · ${t.status}',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AttendanceSourceBadge(source: t.source),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}
