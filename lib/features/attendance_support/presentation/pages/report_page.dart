import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../attendance/presentation/widgets/attendance_source_badge.dart';
import '../bloc/support_cubit.dart';

class NonAppReportPage extends StatefulWidget {
  const NonAppReportPage({super.key});
  @override
  State<NonAppReportPage> createState() => _NonAppReportPageState();
}

class _NonAppReportPageState extends State<NonAppReportPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  void initState() {
    super.initState();
    context.read<ReportCubit>().load(month);
  }

  void move(int n) {
    setState(() => month = DateTime(month.year, month.month + n));
    context.read<ReportCubit>().load(month);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ReportCubit, ReportState>(
    builder: (context, state) => CompactPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(title: 'Non-app attendance'),
          SizedBox(height: 8.h),
          const AppText(
            'Manual entries, corrections and kiosk workdays across your organization.',
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              IconButton(
                onPressed: () => move(-1),
                icon: Icon(Icons.chevron_left, size: 24.r),
              ),
              Expanded(
                child: AppText(
                  DateFormat('MMMM yyyy').format(month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => move(1),
                icon: Icon(Icons.chevron_right, size: 24.r),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (state.status == LoadStatus.loading)
            const Loader()
          else ...[
            if (state.message != null)
              EmptyState(
                title: 'Report could not load',
                message: state.message!,
                onRetry: () => context.read<ReportCubit>().load(month),
              ),
            if (state.records.isEmpty && state.message == null)
              const EmptyState(
                title: 'No non-app records',
                message:
                    'Records will appear here when a fallback method is used.',
              ),
            ...state.records.map((r) {
              final employee = state.snapshot?.employees
                  .where((e) => e.id == r.employeeId)
                  .firstOrNull;
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              employee?.name ?? r.employeeId,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          AttendanceSourceBadge(source: r.source),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      AppText(
                        '${employee?.code ?? ''} · ${DateFormat('dd MMM yyyy').format(r.day)}',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                      SizedBox(height: 8.h),
                      AppText(
                        '${DateFormat('HH:mm').format(r.checkIn.toLocal())} → ${r.checkOut == null ? 'Open' : DateFormat('HH:mm').format(r.checkOut!.toLocal())} · ${r.status}',
                      ),
                      if (r.reason != null) ...[
                        SizedBox(height: 8.h),
                        AppText(
                          'Reason: ${r.reason}',
                          style: TextStyle(fontSize: 13.sp),
                        ),
                      ],
                      TextButton.icon(
                        onPressed: () async {
                          await context.push('/manual-attendance', extra: r);
                          if (context.mounted) {
                            context.read<ReportCubit>().load(month);
                          }
                        },
                        icon: Icon(Icons.edit_outlined, size: 18.r),
                        label: const AppText('Edit with a reason'),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (state.hasMore)
              AppButton(
                label: 'Load more records',
                loading: state.loadingMore,
                onPressed: () => context.read<ReportCubit>().more(),
              ),
          ],
        ],
      ),
    ),
  );
}
