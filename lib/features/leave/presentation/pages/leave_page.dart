import '../../../../core/widgets/app_action_dialog.dart';
import '../../../../core/widgets/app_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../../../core/widgets/month_calendar.dart';
import '../../../../core/domain/page_result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/leave.dart';
import '../bloc/leave_cubit.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});
  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  DateTime month = DateTime.now();
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  @override
  void initState() {
    super.initState();
    context.read<LeaveCubit>().load();
  }

  Future<void> apply(LeaveData data) async {
    String? type;
    bool half = false;
    String period = 'am';
    DateTime start = DateTime.now(), end = DateTime.now();
    final reason = TextEditingController();
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const AppText('Request time off'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChoiceField(
                  label: 'Leave type',
                  items: data.balances
                      .map((b) => Choice(b.type, b.name))
                      .toList(),
                  value: type,
                  required: true,
                  onChanged: (v) => type = v,
                ),
                TextButton(
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 366)),
                    );
                    if (range != null && ctx.mounted) {
                      set(() {
                        start = range.start;
                        end = range.end;
                      });
                    }
                  },
                  child: AppText(
                    '${DateFormat('dd MMM').format(start)} – ${DateFormat('dd MMM').format(end)}',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const AppText('Half day'),
                  value: half,
                  onChanged: (v) => set(() {
                    half = v;
                    if (v) end = start;
                  }),
                ),
                if (half)
                  ChoiceField(
                    label: 'Session',
                    items: const [
                      Choice('am', 'Morning'),
                      Choice('pm', 'Afternoon'),
                    ],
                    value: period,
                    required: true,
                    onChanged: (v) => period = v!,
                  ),
                AppTextField(controller: reason, label: 'Reason'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => dismissAppDialog(ctx),
              child: const AppText('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (type == null || reason.text.trim().length < 3) {
                  toast(context, 'Choose a type and enter a reason.');
                  return;
                }
                final ok = await context.read<LeaveCubit>().apply(
                  type!,
                  start,
                  end,
                  half,
                  half ? period : null,
                  reason.text.trim(),
                );
                if (ok && ctx.mounted) dismissAppDialog(ctx);
              },
              child: const AppText('Submit'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
  }

  Future<void> review(LeaveEntry e, bool approve) async {
    final cubit = context.read<LeaveCubit>();
    await showAppActionDialog(
      context: context,
      title: approve ? 'Approve leave' : 'Reject leave',
      label: 'Review comment',
      onConfirm: (value) async {
        final ok = await cubit.review(e.id, approve, value);
        return ok
            ? null
            : cubit.state.message ??
                  'Unable to complete this action. Please try again.';
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<LeaveCubit, FlowState<LeaveData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      final cubit = context.read<LeaveCubit>();
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Room to recharge'),
            SizedBox(height: 16.h),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    cubit.year--;
                    cubit.load();
                  },
                  icon: Icon(Icons.chevron_left, size: 22.r),
                ),
                Expanded(
                  child: AppText(
                    '${cubit.year} leave year',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    cubit.year++;
                    cubit.load();
                  },
                  icon: Icon(Icons.chevron_right, size: 22.r),
                ),
              ],
            ),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Leave unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: cubit.load,
              )
            else ...[
              ResponsiveTiles(
                children: data.balances
                    .map(
                      (b) => AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              b.name,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            AppText(
                              b.paid ? '${b.remaining}' : 'Unpaid',
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (b.paid)
                              AppText(
                                '${b.used} used / ${b.allocated} days',
                                style: TextStyle(fontSize: 11.sp),
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: 20.h),
              AppButton(
                label: 'Apply for leave',
                loading: state.busy,
                onPressed: () => apply(data),
              ),
              SizedBox(height: 20.h),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Leave calendar',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    MonthCalendar(
                      month: month,
                      onMonth: (v) {
                        setState(() => month = v);
                        if (cubit.year != v.year) {
                          cubit.year = v.year;
                          cubit.load();
                        }
                      },
                      onDay: (v) => setState(() => selected = v),
                      marked: (d) => data.entries.any(
                        (e) =>
                            e.status == 'approved' &&
                            !d.isBefore(e.start) &&
                            !d.isAfter(e.end),
                      ),
                    ),
                    AppText(DateFormat('dd MMM yyyy').format(selected)),
                    ...data.entries
                        .where(
                          (e) =>
                              e.status == 'approved' &&
                              !selected.isBefore(e.start) &&
                              !selected.isAfter(e.end),
                        )
                        .map(
                          (e) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: AppText(e.name),
                            subtitle: AppText(
                              e.half ? 'Half day · ${e.period}' : 'On leave',
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              AppText(
                'Requests & history',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12.h),
              if (data.entries.isEmpty)
                const EmptyState(
                  title: 'No leave requests',
                  message:
                      'Your requests and eligible team requests appear here.',
                ),
              ...data.entries.map(
                (e) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          e.mine ? 'My request' : e.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        AppText(
                          '${DateFormat('dd MMM').format(e.start)} – ${DateFormat('dd MMM').format(e.end)} · ${e.days > 0 ? '${e.days} days' : 'Legacy request'}${e.half ? ' · ${e.period}' : ''}',
                        ),
                        SizedBox(height: 8.h),
                        StatusBadge(
                          label: e.status,
                          color: e.status == 'approved'
                              ? Colors.green
                              : e.status == 'rejected'
                              ? Colors.red
                              : Colors.orange,
                        ),
                        SizedBox(height: 8.h),
                        AppText(e.reason),
                        if (e.comment != null) AppText('Review: ${e.comment}'),
                        if (e.status == 'pending')
                          Wrap(
                            spacing: 8.w,
                            children: [
                              if (e.mine)
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => cubit.cancel(e.id),
                                  child: const AppText('Cancel pending'),
                                )
                              else ...[
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => review(e, true),
                                  child: const AppText('Approve'),
                                ),
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => review(e, false),
                                  child: const AppText('Reject'),
                                ),
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
