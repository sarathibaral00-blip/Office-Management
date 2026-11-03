import '../../../../core/widgets/app_action_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../../../core/domain/page_result.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/financing.dart';
import '../bloc/financing_cubit.dart';

class FinancingPage extends StatefulWidget {
  const FinancingPage({super.key});
  @override
  State<FinancingPage> createState() => _FinancingPageState();
}

class _FinancingPageState extends State<FinancingPage> {
  final amount = TextEditingController(),
      count = TextEditingController(text: '1'),
      reason = TextEditingController();
  String kind = 'advance';
  DateTime month = DateTime.now();
  @override
  void initState() {
    super.initState();
    context.read<FinancingCubit>().load();
  }

  @override
  void dispose() {
    amount.dispose();
    count.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> review(Financing f, String action) async {
    final cubit = context.read<FinancingCubit>();
    await showAppActionDialog(
      context: context,
      title: action == 'disburse'
          ? 'Record disbursement'
          : action == 'approve'
          ? 'Approve request'
          : 'Reject request',
      label: action == 'disburse'
          ? 'Bank / payment reference'
          : 'Review comment',
      onConfirm: (value) async {
        final ok = await cubit.review(f.id, action, value);
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
  ) => BlocConsumer<FinancingCubit, FlowState<FinancingData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      final c = context.read<FinancingCubit>();
      final admin = context.watch<AuthCubit>().state.employee?.isAdmin == true;
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Advances & loans'),
            SizedBox(height: 16.h),
            AppCard(
              child: Column(
                children: [
                  ChoiceField(
                    label: 'Request type',
                    items: const [
                      Choice('advance', 'Salary advance'),
                      Choice('loan', 'Loan'),
                    ],
                    value: kind,
                    required: true,
                    onChanged: (v) => kind = v!,
                  ),
                  AppTextField(
                    controller: amount,
                    label: 'Amount',
                    keyboardType: TextInputType.number,
                  ),
                  AppTextField(
                    controller: count,
                    label: 'Installments (1–120)',
                    keyboardType: TextInputType.number,
                  ),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: month,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2200),
                      );
                      if (d != null) setState(() => month = d);
                    },
                    child: AppText(
                      'Start ${DateFormat('MMMM yyyy').format(month)}',
                    ),
                  ),
                  AppTextField(controller: reason, label: 'Reason'),
                  AppButton(
                    label: 'Submit request',
                    loading: state.busy,
                    onPressed: () async {
                      final a = double.tryParse(amount.text),
                          n = int.tryParse(count.text);
                      if (a == null ||
                          !a.isFinite ||
                          a <= 0 ||
                          n == null ||
                          n < 1 ||
                          n > 120 ||
                          reason.text.trim().length < 3) {
                        toast(context, 'Enter valid terms and a reason.');
                        return;
                      }
                      final ok = await c.request(
                        kind,
                        a,
                        n,
                        month,
                        reason.text.trim(),
                      );
                      if (ok) {
                        amount.clear();
                        reason.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Financing unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: c.load,
              )
            else ...[
              if (data.entries.isEmpty)
                const EmptyState(
                  title: 'No requests yet',
                  message:
                      'Approved disbursements are recovered through locked payroll.',
                ),
              ...data.entries.map(
                (f) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          '${f.name} · ${f.kind}',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppText(
                          '${f.amount.toStringAsFixed(2)} · ${f.installment.toStringAsFixed(2)} per installment',
                        ),
                        AppText(
                          'Repaid ${f.repaid.toStringAsFixed(2)} · Outstanding ${(f.amount - f.repaid).toStringAsFixed(2)}',
                        ),
                        AppText(f.reason),
                        SizedBox(height: 8.h),
                        StatusBadge(
                          label: f.status,
                          color: f.status == 'settled'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        Wrap(
                          children: [
                            if (f.mine && f.status == 'pending')
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => c.review(
                                        f.id,
                                        'withdraw',
                                        'Employee withdrew pending request',
                                      ),
                                child: const AppText('Withdraw'),
                              ),
                            if (admin && !f.mine) ...[
                              if (f.status == 'pending') ...[
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => review(f, 'approve'),
                                  child: const AppText('Approve'),
                                ),
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => review(f, 'reject'),
                                  child: const AppText('Reject'),
                                ),
                              ],
                              if (f.status == 'approved')
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => review(f, 'disburse'),
                                  child: const AppText('Record disbursement'),
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
