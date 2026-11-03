import '../../../../core/widgets/app_action_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/fallback.dart';
import '../bloc/support_cubit.dart';
import '../widgets/support_fields.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.kind});
  final String kind;
  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final form = GlobalKey<FormState>();
  final label = TextEditingController(),
      reason = TextEditingController(),
      pin = TextEditingController();
  String? branch, employee, pinEmployee;
  Timer? timer;
  bool get temporary => widget.kind == 'temporary';
  @override
  void initState() {
    super.initState();
    context.read<DevicesCubit>().load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    label.dispose();
    reason.dispose();
    pin.dispose();
    super.dispose();
  }

  Future<void> launch() async {
    final router = GoRouter.of(context);
    final auth = context.read<AuthCubit>();
    await auth.logout();
    if (auth.state.employee != null) {
      if (mounted) toast(context, 'Sign out could not complete. Please retry.');
      return;
    }
    router.go('/kiosk');
  }

  Future<void> deviceAction(AttendanceDevice d, String action) async {
    final cubit = context.read<DevicesCubit>();
    await showAppActionDialog(
      context: context,
      title: action == 'rotate_device' ? 'Pair this terminal' : 'Revoke device',
      label: 'Reason',
      onConfirm: (value) async {
        final ok = await cubit.manage(action, {'id': d.id, 'reason': value});
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
  ) => BlocConsumer<DevicesCubit, SupportState>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.snapshot;
      final devices =
          data?.devices.where((d) => d.kind == widget.kind).toList() ??
          <AttendanceDevice>[];
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(
              title: temporary ? 'Temporary approvals' : 'Office kiosks',
            ),
            SizedBox(height: 8.h),
            AppText(
              temporary
                  ? 'Approve this terminal for one employee for 24 hours. Every punch still requires office WiFi and their PIN.'
                  : 'Register this terminal while connected to office WiFi. Employees will use their Employee ID and PIN.',
            ),
            SizedBox(height: 20.h),
            if (data == null) ...[
              if (state.status == LoadStatus.loading)
                const Loader()
              else
                EmptyState(
                  title: 'Devices unavailable',
                  message: state.message ?? 'Please retry.',
                  onRetry: () => context.read<DevicesCubit>().load(),
                ),
            ] else ...[
              AppCard(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Approve this device',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(controller: label, label: 'Device label'),
                      Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: DropdownButtonFormField<String>(
                          initialValue: branch,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            label: AppText('Office branch'),
                          ),
                          items: data.branches
                              .map(
                                (b) => DropdownMenuItem(
                                  value: b.id,
                                  child: AppText(
                                    b.name,
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            branch = v;
                            employee = null;
                          }),
                          validator: (v) =>
                              v == null ? 'Choose a branch' : null,
                        ),
                      ),
                      if (temporary)
                        EmployeeField(
                          employees: data.employees
                              .where(
                                (e) => branch == null || e.branchId == branch,
                              )
                              .toList(),
                          value: employee,
                          onChanged: (v) => setState(() => employee = v),
                        ),
                      AppTextField(
                        controller: reason,
                        label: 'Approval reason',
                        validator: (v) => v == null || v.trim().length < 3
                            ? 'Enter a reason (at least 3 characters)'
                            : null,
                      ),
                      AppButton(
                        label: temporary
                            ? 'Approve for one day'
                            : 'Register kiosk',
                        loading: state.busy,
                        onPressed: () async {
                          if (!form.currentState!.validate()) return;
                          await context
                              .read<DevicesCubit>()
                              .manage('register_device', {
                                'label': label.text.trim(),
                                'kind': widget.kind,
                                'branch_id': branch,
                                'employee_id': temporary ? employee : null,
                                'reason': reason.text.trim(),
                              });
                        },
                      ),
                      if (state.paired) ...[
                        SizedBox(height: 12.h),
                        AppButton(
                          label: 'Sign out HR & open employee terminal',
                          icon: Icons.lock_outline,
                          onPressed: launch,
                        ),
                      ],
                      SizedBox(height: 12.h),
                      AppText(
                        'Pairing stays only in this app session. After a reload, sign in as HR and use “Pair here” to rotate the credential.',
                        style: TextStyle(fontSize: 12.sp),
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
                      'Set / reset employee PIN',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    const AppText(
                      'Reset unlocks an employee after five failed attempts. PINs cannot be viewed or recovered.',
                    ),
                    SizedBox(height: 16.h),
                    EmployeeField(
                      employees: data.employees,
                      value: pinEmployee,
                      onChanged: (v) => setState(() => pinEmployee = v),
                    ),
                    AppTextField(
                      controller: pin,
                      label: 'New PIN (6–12 digits)',
                      obscure: true,
                      keyboardType: TextInputType.number,
                    ),
                    AppButton(
                      label: 'Set secure PIN',
                      loading: state.busy,
                      onPressed: () async {
                        if (pinEmployee == null ||
                            !RegExp(r'^[0-9]{6,12}$').hasMatch(pin.text)) {
                          toast(
                            context,
                            'Choose an employee and enter 6–12 digits.',
                          );
                          return;
                        }
                        final value = pin.text;
                        pin.clear();
                        await context.read<DevicesCubit>().manage('set_pin', {
                          'employee_id': pinEmployee,
                          'pin': value,
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              AppText(
                'Approved devices',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12.h),
              if (devices.isEmpty)
                const EmptyState(
                  title: 'No devices yet',
                  message: 'Register the current terminal to get started.',
                )
              else
                ...devices.map(
                  (d) => Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            d.label,
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          StatusBadge(
                            label: d.status(DateTime.now()),
                            color: d.active(DateTime.now())
                                ? const Color(0xFF2E7D32)
                                : Colors.grey,
                          ),
                          SizedBox(height: 8.h),
                          AppText(
                            data.branches
                                    .where((b) => b.id == d.branchId)
                                    .firstOrNull
                                    ?.name ??
                                'Branch unavailable',
                          ),
                          if (d.employeeId != null)
                            AppText(
                              data.employees
                                      .where((e) => e.id == d.employeeId)
                                      .map((e) => '${e.code} · ${e.name}')
                                      .firstOrNull ??
                                  'Employee unavailable',
                            ),
                          if (d.expiresAt != null)
                            AppText(
                              'Expires ${DateFormat('dd MMM, HH:mm').format(d.expiresAt!.toLocal())}',
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          Wrap(
                            spacing: 8.w,
                            children: [
                              TextButton(
                                onPressed:
                                    !d.active(DateTime.now()) || state.busy
                                    ? null
                                    : () => deviceAction(d, 'rotate_device'),
                                child: const AppText('Pair here'),
                              ),
                              TextButton(
                                onPressed: d.revokedAt != null || state.busy
                                    ? null
                                    : () => deviceAction(d, 'revoke_device'),
                                child: const AppText('Revoke'),
                              ),
                            ],
                          ),
                          if (state.paired)
                            TextButton(
                              onPressed: launch,
                              child: const AppText('Open paired terminal'),
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
