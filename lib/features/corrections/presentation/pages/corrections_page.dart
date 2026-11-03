import '../../../../core/widgets/app_action_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../attendance_support/presentation/widgets/support_fields.dart';
import '../../domain/entities/corrections.dart';
import '../bloc/corrections_cubit.dart';

class CorrectionsPage extends StatefulWidget {
  const CorrectionsPage({super.key});
  @override
  State<CorrectionsPage> createState() => _CorrectionsPageState();
}

class _CorrectionsPageState extends State<CorrectionsPage> {
  String? attendance;
  DateTime? checkIn, checkOut;
  final reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    context.read<CorrectionsCubit>().load();
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> review(Correction c, bool approve) async {
    final cubit = context.read<CorrectionsCubit>();
    await showAppActionDialog(
      context: context,
      title: approve ? 'Approve correction' : 'Reject correction',
      label: 'Review comment',
      onConfirm: (value) async {
        final ok = await cubit.review(c.id, approve, value);
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
  ) => BlocConsumer<CorrectionsCubit, FlowState<CorrectionData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      final cubit = context.read<CorrectionsCubit>();
      final admin = context.watch<AuthCubit>().state.employee?.isAdmin == true;
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Make the record right'),
            SizedBox(height: 8.h),
            const AppText(
              'Request a change to an existing workday. For a wholly missing day, ask HR for manual attendance.',
            ),
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
                  child: AppText('${cubit.year}', textAlign: TextAlign.center),
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
                title: 'Requests unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: cubit.load,
              )
            else ...[
              AppCard(
                child: Column(
                  children: [
                    ChoiceField(
                      label: 'My workday',
                      items: data.attendance,
                      value: attendance,
                      required: true,
                      onChanged: (v) => attendance = v,
                    ),
                    const AppText(
                      'Enter corrected times in this device’s timezone.',
                    ),
                    SizedBox(height: 12.h),
                    TimeField(
                      label: 'Correct check in',
                      value: checkIn,
                      onChanged: (v) => setState(() => checkIn = v),
                    ),
                    TimeField(
                      label: 'Correct check out (optional)',
                      value: checkOut,
                      onChanged: (v) => setState(() => checkOut = v),
                      optional: true,
                    ),
                    AppTextField(controller: reason, label: 'Reason'),
                    AppButton(
                      label: 'Send correction request',
                      loading: state.busy,
                      onPressed: () async {
                        if (attendance == null ||
                            checkIn == null ||
                            reason.text.trim().length < 3) {
                          toast(
                            context,
                            'Choose a workday, check-in time and reason.',
                          );
                          return;
                        }
                        final ok = await cubit.request(
                          attendance!,
                          checkIn!,
                          checkOut,
                          reason.text.trim(),
                        );
                        if (ok && mounted) {
                          setState(() {
                            reason.clear();
                            attendance = null;
                            checkIn = null;
                            checkOut = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              ...data.requests.map(
                (c) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          c.mine ? 'My correction' : c.name,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        AppText(
                          '${DateFormat('dd MMM, HH:mm').format(c.checkIn.toLocal())} → ${c.checkOut == null ? 'Open' : DateFormat('dd MMM, HH:mm').format(c.checkOut!.toLocal())}',
                        ),
                        AppText(c.reason),
                        if (c.comment != null) AppText('Review: ${c.comment}'),
                        SizedBox(height: 8.h),
                        StatusBadge(
                          label: c.status,
                          color: c.status == 'approved'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        if (admin && !c.mine && c.status == 'pending')
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => review(c, true),
                                child: const AppText('Approve'),
                              ),
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => review(c, false),
                                child: const AppText('Reject'),
                              ),
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
