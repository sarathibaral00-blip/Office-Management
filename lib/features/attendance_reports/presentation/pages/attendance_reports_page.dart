import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../attendance/presentation/widgets/attendance_source_badge.dart';
import '../../domain/entities/attendance_reports.dart';
import '../bloc/attendance_reports_cubit.dart';

class AttendanceReportsPage extends StatefulWidget {
  const AttendanceReportsPage({super.key});
  @override
  State<AttendanceReportsPage> createState() => _AttendanceReportsPageState();
}

class _AttendanceReportsPageState extends State<AttendanceReportsPage> {
  @override
  void initState() {
    super.initState();
    context.read<AttendanceReportsCubit>().load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AttendanceReportsCubit, FlowState<AttendanceReportData>>(
    builder: (context, state) {
      final data = state.data;
      final c = context.read<AttendanceReportsCubit>();
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Attendance reports'),
            SizedBox(height: 16.h),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const AppText('Monthly report'),
              value: c.monthly,
              onChanged: (v) {
                c.monthly = v;
                c.load();
              },
            ),
            TextButton.icon(
              onPressed: () async {
                final day = await showDatePicker(
                  context: context,
                  initialDate: c.day,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2200),
                );
                if (day != null) {
                  c.day = day;
                  c.load();
                }
              },
              icon: Icon(Icons.calendar_month, size: 20.r),
              label: AppText(
                DateFormat(
                  c.monthly ? 'MMMM yyyy' : 'dd MMM yyyy',
                ).format(c.day),
              ),
            ),
            if (data != null) ...[
              ChoiceField(
                label: 'Department',
                items: data.departments,
                value: c.department,
                onChanged: (v) {
                  c.department = v;
                  c.load();
                },
              ),
              ChoiceField(
                label: 'Branch',
                items: data.branches,
                value: c.branch,
                onChanged: (v) {
                  c.branch = v;
                  c.load();
                },
              ),
            ],
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Reports unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: () => c.load(),
              )
            else ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      '${data.total} employee-days',
                      style: TextStyle(
                        fontSize: 21.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        StatusBadge(
                          label: 'Present ${data.present}',
                          color: Colors.green,
                        ),
                        StatusBadge(
                          label: 'Late ${data.late}',
                          color: Colors.orange,
                        ),
                        StatusBadge(
                          label: 'Absent ${data.absent}',
                          color: Colors.red,
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    AppText('${data.hours.toStringAsFixed(1)} completed hours'),
                    AppText(
                      'Historical department and inferred schedules use current assignments.',
                      style: TextStyle(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              if (data.page.items.isEmpty)
                const EmptyState(
                  title: 'No matching employees',
                  message: 'Try another period, department or branch.',
                ),
              ...data.page.items.map(
                (r) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          r.name,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppText(
                          '${r.code} · ${DateFormat('dd MMM yyyy').format(r.day)}',
                          style: TextStyle(fontSize: 12.sp),
                        ),
                        SizedBox(height: 8.h),
                        AppText('${r.department} · ${r.branch}'),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 8.w,
                          children: [
                            StatusBadge(
                              label: r.status.replaceAll('_', ' '),
                              color: r.status == 'late'
                                  ? Colors.orange
                                  : r.status == 'absent'
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            AttendanceSourceBadge(source: r.source),
                          ],
                        ),
                        if (r.checkIn != null) ...[
                          SizedBox(height: 8.h),
                          AppText(
                            '${DateFormat('HH:mm').format(r.checkIn!.toLocal())} → ${r.checkOut == null ? 'Open' : DateFormat('HH:mm').format(r.checkOut!.toLocal())} · ${r.hours.toStringAsFixed(1)}h',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (data.page.hasMore)
                AppButton(
                  label: 'Load more records',
                  loading: state.busy,
                  onPressed: () => c.load(more: true),
                ),
            ],
          ],
        ),
      );
    },
  );
}
