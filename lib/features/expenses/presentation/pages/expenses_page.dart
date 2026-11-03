import '../../../../core/widgets/app_action_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/expenses.dart';
import '../bloc/expenses_cubit.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final title = TextEditingController(),
      category = TextEditingController(text: 'Office'),
      amount = TextEditingController();
  DateTime day = DateTime.now();
  @override
  void initState() {
    super.initState();
    context.read<ExpensesCubit>().load();
  }

  @override
  void dispose() {
    title.dispose();
    category.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> review(Expense e, String action) async {
    final cubit = context.read<ExpensesCubit>();
    await showAppActionDialog(
      context: context,
      title: action == 'reimburse'
          ? 'Record reimbursement'
          : action == 'approve'
          ? 'Approve expense'
          : 'Reject expense',
      label: action == 'reimburse' ? 'Payment reference' : 'Review comment',
      onConfirm: (value) async {
        final ok = await cubit.review(e.id, action, value);
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
  ) => BlocConsumer<ExpensesCubit, FlowState<ExpenseData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      final c = context.read<ExpensesCubit>();
      final admin = context.watch<AuthCubit>().state.employee?.isAdmin == true;
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Expense claims'),
            SizedBox(height: 20.h),
            AppCard(
              child: Column(
                children: [
                  AppTextField(controller: title, label: 'Expense title'),
                  AppTextField(controller: category, label: 'Category'),
                  AppTextField(
                    controller: amount,
                    label: 'Amount',
                    keyboardType: TextInputType.number,
                  ),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: day,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => day = d);
                    },
                    child: AppText(DateFormat('dd MMM yyyy').format(day)),
                  ),
                  AppButton(
                    label: c.receiptPath == null
                        ? 'Upload receipt'
                        : 'Replace uploaded receipt',
                    loading: state.busy,
                    onPressed: c.upload,
                  ),
                  SizedBox(height: 12.h),
                  AppButton(
                    label: 'Submit claim',
                    loading: state.busy,
                    onPressed: () async {
                      final a = double.tryParse(amount.text);
                      if (a == null ||
                          !a.isFinite ||
                          a <= 0 ||
                          title.text.trim().length < 3) {
                        toast(context, 'Enter a title and valid amount.');
                        return;
                      }
                      final ok = await c.submit(
                        title.text.trim(),
                        category.text.trim(),
                        a,
                        day,
                      );
                      if (ok) {
                        title.clear();
                        amount.clear();
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
                title: 'Claims unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: c.load,
              )
            else ...[
              if (data.claims.isEmpty)
                const EmptyState(
                  title: 'No claims yet',
                  message: 'Upload your receipt and submit a claim.',
                ),
              ...data.claims.map(
                (e) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          '${e.name} · ${e.title}',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppText(
                          '${DateFormat('dd MMM yyyy').format(e.day)} · ${e.amount.toStringAsFixed(2)}',
                        ),
                        SizedBox(height: 8.h),
                        StatusBadge(
                          label: e.status,
                          color: e.status == 'reimbursed'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        if (e.comment != null) AppText(e.comment!),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: state.busy
                                  ? null
                                  : () => c.receipt(e.receipt),
                              child: const AppText('Download receipt'),
                            ),
                            if (e.mine && e.status == 'pending')
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => c.review(
                                        e.id,
                                        'withdraw',
                                        'Employee withdrew claim',
                                      ),
                                child: const AppText('Withdraw'),
                              ),
                            if (admin && !e.mine) ...[
                              if (e.status == 'pending') ...[
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => review(e, 'approve'),
                                  child: const AppText('Approve'),
                                ),
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => review(e, 'reject'),
                                  child: const AppText('Reject'),
                                ),
                              ],
                              if (e.status == 'approved')
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => review(e, 'reimburse'),
                                  child: const AppText('Record reimbursement'),
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
