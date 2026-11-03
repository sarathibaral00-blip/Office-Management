import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/fallback.dart';
import '../bloc/support_cubit.dart';
import '../widgets/support_fields.dart';

class ManualPage extends StatefulWidget {
  const ManualPage({super.key, this.initial});
  final SupportRecord? initial;
  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  final limit = TextEditingController();
  final policyReason = TextEditingController();
  String? employee, recordId;
  DateTime day = DateTime.now();
  DateTime? checkIn, checkOut;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      employee = initial.employeeId;
      recordId = initial.id;
      day = initial.day;
      checkIn = initial.checkIn.toLocal();
      checkOut = initial.checkOut?.toLocal();
    }
    context.read<ManualCubit>().load();
  }

  @override
  void dispose() {
    reason.dispose();
    limit.dispose();
    policyReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ManualCubit, SupportState>(
    listenWhen: (a, b) => a.message != b.message || a.revision != b.revision,
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
      if (state.revision > 0) {
        final record = state.record;
        setState(() {
          recordId = record?.id;
          checkIn = record?.checkIn.toLocal();
          checkOut = record?.checkOut?.toLocal();
          reason.clear();
        });
      }
    },
    builder: (context, state) {
      final data = state.snapshot;
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Manual attendance'),
            SizedBox(height: 8.h),
            const AppText(
              'Every change needs a reason and is recorded in the audit log.',
            ),
            SizedBox(height: 20.h),
            if (data == null) ...[
              if (state.status == LoadStatus.loading)
                const Loader()
              else
                EmptyState(
                  title: 'Unable to load employees',
                  message: state.message ?? 'Try again.',
                  onRetry: () => context.read<ManualCubit>().load(),
                ),
            ] else ...[
              AppCard(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EmployeeField(
                        employees: data.employees,
                        value: employee,
                        onChanged: state.busy || recordId != null
                            ? null
                            : (v) => setState(() {
                                employee = v;
                                recordId = null;
                                checkIn = null;
                                checkOut = null;
                              }),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              'Work date: ${DateFormat('dd MMM yyyy').format(day)}',
                              style: TextStyle(fontSize: 14.sp),
                            ),
                          ),
                          TextButton(
                            onPressed: state.busy || recordId != null
                                ? null
                                : () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: day,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                    );
                                    if (d != null) setState(() => day = d);
                                  },
                            child: const AppText('Choose'),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: state.busy || employee == null
                            ? null
                            : () => context.read<ManualCubit>().find(
                                employee!,
                                day,
                              ),
                        icon: Icon(Icons.search, size: 18.r),
                        label: const AppText('Load existing record'),
                      ),
                      if (recordId != null)
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                'Editing an existing record',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: state.busy
                                  ? null
                                  : () => setState(() {
                                      recordId = null;
                                      reason.clear();
                                      checkIn = null;
                                      checkOut = null;
                                    }),
                              child: const AppText('Clear'),
                            ),
                          ],
                        ),
                      SizedBox(height: 16.h),
                      const AppText(
                        'Times below use this device’s timezone. The server derives the work date in the employee’s branch timezone.',
                      ),
                      SizedBox(height: 16.h),
                      TimeField(
                        label: 'Check in',
                        value: checkIn,
                        onChanged: (v) => setState(() => checkIn = v),
                      ),
                      TimeField(
                        label: 'Check out (optional)',
                        value: checkOut,
                        onChanged: (v) => setState(() => checkOut = v),
                        optional: true,
                      ),
                      AppTextField(
                        controller: reason,
                        label: 'Reason for this change',
                        validator: (v) => v == null || v.trim().length < 3
                            ? 'Enter a reason (at least 3 characters)'
                            : v.length > 1000
                            ? 'Use at most 1000 characters'
                            : null,
                      ),
                      AppButton(
                        label: recordId == null
                            ? 'Add manual attendance'
                            : 'Save manual changes',
                        loading: state.busy,
                        onPressed: () async {
                          if (!form.currentState!.validate()) return;
                          if (checkIn == null) {
                            toast(context, 'Choose a check-in time.');
                            return;
                          }
                          if (checkOut != null &&
                              checkOut!.isBefore(checkIn!)) {
                            toast(context, 'Check out must be after check in.');
                            return;
                          }
                          final ok = await context.read<ManualCubit>().submit(
                            ManualSubmission(
                              employeeId: employee!,
                              checkIn: checkIn!,
                              checkOut: checkOut,
                              reason: reason.text.trim(),
                              attendanceId: recordId,
                            ),
                          );
                          if (ok && mounted) {
                            setState(() {
                              recordId = null;
                              reason.clear();
                              checkIn = null;
                              checkOut = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Monthly policy',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    AppText(
                      'Current limit: ${data.limit} distinct manual records per employee. Records are allowed above the limit and HR receives an alert.',
                    ),
                    SizedBox(height: 16.h),
                    AppTextField(
                      controller: limit,
                      label: 'New monthly limit (0–100)',
                      keyboardType: TextInputType.number,
                    ),
                    AppTextField(
                      controller: policyReason,
                      label: 'Reason for changing the limit',
                    ),
                    AppButton(
                      label: 'Update monthly limit',
                      loading: state.busy,
                      onPressed: () {
                        final value = int.tryParse(limit.text);
                        if (value == null ||
                            value < 0 ||
                            value > 100 ||
                            policyReason.text.trim().length < 3) {
                          toast(
                            context,
                            'Enter a limit from 0–100 and a reason.',
                          );
                          return;
                        }
                        context.read<ManualCubit>().manage('set_limit', {
                          'limit': value,
                          'reason': policyReason.text.trim(),
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              AppText(
                'HR alerts',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12.h),
              if (data.alerts.isEmpty)
                const EmptyState(
                  title: 'All caught up',
                  message: 'No unacknowledged manual-attendance alerts.',
                )
              else
                ...data.alerts.map(
                  (a) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(
                            label: 'Manual limit exceeded',
                            color: const Color(0xFFED9B00),
                          ),
                          SizedBox(height: 12.h),
                          AppText(a.message),
                          TextButton(
                            onPressed: state.busy
                                ? null
                                : () => context.read<ManualCubit>().manage(
                                    'ack_alert',
                                    {'id': a.id},
                                  ),
                            child: const AppText('Acknowledge'),
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
