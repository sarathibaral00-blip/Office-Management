import '../widgets/salary_structure_sheet.dart';
import '../../../../core/widgets/app_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../../core/error/result.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/payroll.dart';
import '../bloc/payroll_cubit.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});
  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  @override
  void initState() {
    super.initState();
    context.read<PayrollCubit>().load();
  }

  Future<void> salary(PayrollData data) {
    final cubit = context.read<PayrollCubit>();
    return showSalaryStructureSheet(
      context: context,
      data: data,
      onSave: (employee, values) async {
        final ok = await cubit.salary(employee, values);
        return ok
            ? null
            : cubit.state.message ?? 'Unable to save salary structure.';
      },
    );
  }

  Future<void> adjust(Payslip p) async {
    final bonus = TextEditingController(text: p.bonus.toString()),
        extra = TextEditingController(text: p.extra.toString()),
        reason = TextEditingController();
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Draft adjustment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: bonus,
                label: 'Bonus',
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: extra,
                label: 'Additional deduction',
                keyboardType: TextInputType.number,
              ),
              AppTextField(controller: reason, label: 'Required reason'),
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
              final b = double.tryParse(bonus.text),
                  e = double.tryParse(extra.text);
              if (b == null || e == null || reason.text.trim().length < 3) {
                return;
              }
              final ok = await context.read<PayrollCubit>().adjust(
                p.id,
                b,
                e,
                reason.text.trim(),
              );
              if (ok && ctx.mounted) dismissAppDialog(ctx);
            },
            child: const AppText('Save'),
          ),
        ],
      ),
    );
    bonus.dispose();
    extra.dispose();
    reason.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<PayrollCubit, FlowState<PayrollData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      final c = context.read<PayrollCubit>();
      final admin = context.watch<AuthCubit>().state.employee?.isAdmin == true;
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: admin ? 'Payroll workspace' : 'My payslips'),
            SizedBox(height: 12.h),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    c.year--;
                    c.load();
                  },
                  icon: Icon(Icons.chevron_left, size: 22.r),
                ),
                Expanded(
                  child: AppText('${c.year}', textAlign: TextAlign.center),
                ),
                IconButton(
                  onPressed: () {
                    c.year++;
                    c.load();
                  },
                  icon: Icon(Icons.chevron_right, size: 22.r),
                ),
              ],
            ),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Payroll unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: c.load,
              )
            else ...[
              if (admin) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Net total: ${data.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 23.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      AppText('${data.slips.length} payslips in this year'),
                      SizedBox(height: 16.h),
                      AppButton(
                        label: 'Generate closed-month payroll',
                        loading: state.busy,
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime(
                              DateTime.now().year,
                              DateTime.now().month - 1,
                            ),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) await c.generate(date);
                        },
                      ),
                      TextButton(
                        onPressed: state.busy ? null : () => salary(data),
                        child: const AppText('Salary structure & bank details'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                ...data.runs.map(
                  (r) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            DateFormat('MMMM yyyy').format(r.month),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          StatusBadge(
                            label: r.status,
                            color: r.status == 'locked'
                                ? Colors.green
                                : Colors.orange,
                          ),
                          Wrap(
                            children: [
                              if (r.status == 'draft')
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => c.transition(r.id, 'approve'),
                                  child: const AppText(
                                    'Approve (another reviewer)',
                                  ),
                                ),
                              if (r.status == 'approved')
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => c.transition(r.id, 'lock'),
                                  child: const AppText('Lock & publish'),
                                ),
                              if (r.status == 'locked')
                                TextButton(
                                  onPressed: state.busy
                                      ? null
                                      : () => c.bank(r.id),
                                  child: const AppText('Bank sheet CSV'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (data.slips.isEmpty)
                const EmptyState(
                  title: 'No payslips yet',
                  message:
                      'Locked payslips will appear here after payroll approval.',
                ),
              ...data.slips.map(
                (p) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          p.name,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppText(
                          '${DateFormat('MMMM yyyy').format(p.month)} · ${p.currency} ${p.net.toStringAsFixed(2)}',
                        ),
                        SizedBox(height: 8.h),
                        StatusBadge(
                          label: p.locked ? 'Locked' : p.source,
                          color: p.locked ? Colors.green : Colors.orange,
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: AppText(
                            'Components',
                            style: TextStyle(fontSize: 14.sp),
                          ),
                          children: p.lines
                              .map(
                                (line) => Padding(
                                  padding: EdgeInsets.only(bottom: 6.h),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: AppText(
                                          '${line[0]}',
                                          style: TextStyle(fontSize: 12.sp),
                                        ),
                                      ),
                                      AppText(
                                        '${line[1]}',
                                        style: TextStyle(fontSize: 12.sp),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        Wrap(
                          children: [
                            if (p.locked) ...[
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => c.payslip(p.id, false),
                                child: const AppText('Download PDF'),
                              ),
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => c.payslip(p.id, true),
                                child: const AppText('Share PDF'),
                              ),
                            ] else if (admin)
                              TextButton(
                                onPressed: state.busy ? null : () => adjust(p),
                                child: const AppText('Bonus / adjustment'),
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
