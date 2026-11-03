import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/attendance.dart';
import '../bloc/attendance_cubit.dart';
import '../widgets/attendance_source_badge.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  void initState() {
    super.initState();
    context.read<HistoryCubit>().load(month);
  }

  void move(int n) {
    setState(() => month = DateTime(month.year, month.month + n));
    context.read<HistoryCubit>().load(month);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<HistoryCubit, AttendanceState>(
    builder: (context, state) {
      final data = state.month;
      final rows = data?.records ?? <Attendance>[];
      String status(DateTime d) {
        final record = rows.where((a) => a.day.day == d.day).firstOrNull;
        if (record != null) return record.status;
        if (data?.holidays.contains(WorkMonth.key(d)) == true) return 'holiday';
        if ((data?.leaveUnits[WorkMonth.key(d)] ?? 0) >= 1) return 'leave';
        if (data != null &&
            d.isBefore(
              DateTime(data.today.year, data.today.month, data.today.day),
            ) &&
            data.scheduled(d)) {
          return 'absent';
        }
        return 'off';
      }

      Color color(String s) => switch (s) {
        'holiday' => Theme.of(context).colorScheme.primary,
        'leave' => Colors.blue,
        'present' => const Color(0xFF2E7D32),
        'late' => const Color(0xFFED9B00),
        'absent' => const Color(0xFFD32F2F),
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };
      final days = DateTime(month.year, month.month + 1, 0).day;
      final counts = {
        for (final s in ['present', 'late', 'absent'])
          s:
              List.generate(
                    days,
                    (i) => DateTime(month.year, month.month, i + 1),
                  )
                  .where((d) => status(d) == s)
                  .fold<double>(
                    0,
                    (sum, d) =>
                        sum +
                        (s == 'absent'
                            ? (1 - (data?.leaveUnits[WorkMonth.key(d)] ?? 0))
                                  .clamp(0, 1)
                            : 1),
                  ),
      };
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Your attendance'),
            SizedBox(height: 8.h),
            const AppText('A clear picture of your workdays.'),
            SizedBox(height: 20.h),
            Row(
              children: [
                IconButton(
                  onPressed: () => move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: AppText(
                    DateFormat('MMMM yyyy').format(month),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Could not load attendance',
                message: state.message ?? 'Try again.',
                onRetry: () => context.read<HistoryCubit>().load(month),
              )
            else ...[
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                          .map(
                            (s) => Expanded(
                              child: Center(
                                child: AppText(
                                  s,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(height: 12.h),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: days + month.weekday - 1,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 6.h,
                        crossAxisSpacing: 4.w,
                      ),
                      itemBuilder: (context, i) {
                        final day = i - month.weekday + 2;
                        if (day < 1) return const SizedBox.shrink();
                        final d = DateTime(month.year, month.month, day);
                        final s = status(d);
                        final c = color(s);
                        return Tooltip(
                          message:
                              data.holidayNames[WorkMonth.key(d)] ??
                              (s == 'leave'
                                  ? 'Approved leave'
                                  : s == 'off'
                                  ? 'Non-working, today, or upcoming'
                                  : s),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: s == 'off'
                                  ? Colors.transparent
                                  : c.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: AppText(
                              '$day',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: c,
                                fontWeight: s == 'off'
                                    ? FontWeight.w400
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children:
                          ['present', 'late', 'absent', 'holiday', 'leave']
                              .map(
                                (s) => StatusBadge(label: s, color: color(s)),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              if (data.holidayNames.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Office holidays',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ...data.holidayNames.entries.map(
                        (h) => Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: AppText(
                            '${h.key} · ${h.value}',
                            style: TextStyle(fontSize: 13.sp),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 16.h),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Monthly summary',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      children: counts.entries
                          .map(
                            (e) => Expanded(
                              child: Column(
                                children: [
                                  AppText(
                                    '${e.value}',
                                    style: TextStyle(
                                      fontSize: 26.sp,
                                      fontWeight: FontWeight.w800,
                                      color: color(e.key),
                                    ),
                                  ),
                                  AppText(
                                    e.key,
                                    style: TextStyle(fontSize: 12.sp),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(height: 16.h),
                    AppText(
                      '${(rows.fold<int>(0, (n, a) => n + (a.checkOut == null ? 0 : a.hours(a.checkOut!).inMinutes)) / 60).toStringAsFixed(1)} completed hours',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              if (rows.isEmpty)
                const EmptyState(
                  title: 'No check-ins yet',
                  message: 'Your workdays will appear here.',
                )
              else
                ...rows.reversed.map(
                  (a) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  DateFormat('EEE, MMM d').format(a.day),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                AppText(
                                  '${DateFormat('hh:mm a').format(a.checkIn.toLocal())} → ${a.checkOut == null ? 'Working' : DateFormat('hh:mm a').format(a.checkOut!.toLocal())}',
                                  style: TextStyle(fontSize: 12.sp),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(
                                label: a.status,
                                color: color(a.status),
                              ),
                              if (a.source != 'app') ...[
                                SizedBox(height: 6.h),
                                AttendanceSourceBadge(source: a.source),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}
