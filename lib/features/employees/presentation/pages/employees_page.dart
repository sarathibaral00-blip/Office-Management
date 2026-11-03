import 'package:flutter/services.dart';
import '../../../../core/widgets/app_action_dialog.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../../core/error/result.dart';
import '../../../../core/domain/page_result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../domain/entities/employees.dart';
import '../bloc/employees_cubit.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});
  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final search = TextEditingController();
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    context.read<EmployeesCubit>().load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> open(Directory directory, [Staff? staff]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) => di<EmployeeDetailCubit>(),
          child: EmployeeDetailPage(directory: directory, staff: staff),
        ),
      ),
    );
    if (mounted) context.read<EmployeesCubit>().load();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<EmployeesCubit, FlowState<Directory>>(
        builder: (context, state) {
          final data = state.data;
          final cubit = context.read<EmployeesCubit>();
          return CompactPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeading(title: 'Our people'),
                SizedBox(height: 8.h),
                const AppText('Find, support and organize your team.'),
                SizedBox(height: 20.h),
                AppTextField(
                  controller: search,
                  label: 'Search name, ID or email',
                  onChanged: (value) {
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 350), () {
                      if (mounted) {
                        cubit.search = value;
                        cubit.load();
                      }
                    });
                  },
                ),
                TextButton(
                  onPressed: () {
                    cubit.search = search.text;
                    cubit.load();
                  },
                  child: const AppText('Search'),
                ),
                if (data != null) ...[
                  ChoiceField(
                    label: 'Department',
                    items: data.departments,
                    value: cubit.department,
                    onChanged: (v) {
                      cubit.department = v;
                      cubit.load();
                    },
                  ),
                  ChoiceField(
                    label: 'Branch',
                    items: data.branches,
                    value: cubit.branch,
                    onChanged: (v) {
                      cubit.branch = v;
                      cubit.load();
                    },
                  ),
                  ChoiceField(
                    label: 'Status',
                    items: const [
                      Choice('active', 'Active'),
                      Choice('inactive', 'Inactive'),
                    ],
                    value: cubit.active == null
                        ? null
                        : cubit.active!
                        ? 'active'
                        : 'inactive',
                    onChanged: (v) {
                      cubit.active = v == null ? null : v == 'active';
                      cubit.load();
                    },
                  ),
                  AppButton(
                    label: 'Add employee',
                    icon: Icons.person_add_alt,
                    onPressed: () => open(data),
                  ),
                  SizedBox(height: 20.h),
                ],
                if (state.status == LoadStatus.loading)
                  const Loader()
                else if (data == null)
                  EmptyState(
                    title: 'People unavailable',
                    message: state.message ?? 'Please retry.',
                    onRetry: () => cubit.load(),
                  )
                else ...[
                  if (state.message != null) AppText(state.message!),
                  if (data.page.items.isEmpty)
                    const EmptyState(
                      title: 'No employees found',
                      message: 'Try a different search or filter.',
                    ),
                  ...data.page.items.map(
                    (e) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: AppCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: AppText(
                            e.name,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: AppText(
                            '${e.code} · ${e.designation ?? e.role}',
                          ),
                          trailing: StatusBadge(
                            label: e.active ? 'Active' : 'Inactive',
                            color: e.active ? Colors.green : Colors.grey,
                          ),
                          onTap: () => open(data, e),
                        ),
                      ),
                    ),
                  ),
                  if (data.page.hasMore)
                    AppButton(
                      label: 'Load more',
                      loading: state.busy,
                      onPressed: () => cubit.load(more: true),
                    ),
                ],
              ],
            ),
          );
        },
      );
}

class EmployeeDetailPage extends StatefulWidget {
  const EmployeeDetailPage({super.key, required this.directory, this.staff});
  final Directory directory;
  final Staff? staff;
  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.staff?.name),
      email = TextEditingController(text: widget.staff?.email),
      salary = TextEditingController(text: widget.staff?.salary.toString()),
      designation = TextEditingController(text: widget.staff?.designation);
  final password = TextEditingController(), pin = TextEditingController();
  late String role = widget.staff?.role ?? 'employee';
  late final departments = [...widget.directory.departments];
  late String? department = widget.staff?.department,
      branch = widget.staff?.branch,
      manager = widget.staff?.manager,
      shift = widget.staff?.shift;
  late bool active = widget.staff?.active ?? true;
  @override
  void dispose() {
    for (final c in [name, email, salary, designation, password, pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> addDepartment() async {
    final cubit = context.read<EmployeeDetailCubit>();
    await showAppActionDialog(
      context: context,
      title: 'Add department',
      label: 'Department name',
      confirmLabel: 'Add department',
      minimumLength: 2,
      onConfirm: (name) async {
        final result = await cubit.createDepartment(name);
        if (result == null) {
          return cubit.state.message ?? 'Unable to add department.';
        }
        if (mounted) {
          setState(() {
            departments.add(result);
            department = result.id;
          });
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText(widget.staff?.code ?? 'New employee')),
    body: BlocConsumer<EmployeeDetailCubit, FlowState<Staff>>(
      listener: (context, state) {
        if (state.message != null) toast(context, state.message!);
      },
      builder: (context, state) => CompactPageBody(
        child: Form(
          key: form,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  widget.staff == null
                      ? 'Welcome someone new'
                      : widget.staff!.name,
                  style: TextStyle(
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.staff != null)
                  AppText(
                    widget.staff!.email,
                    style: TextStyle(fontSize: 13.sp),
                  ),
                SizedBox(height: 20.h),
                AppTextField(controller: name, label: 'Full name'),
                if (widget.staff == null) ...[
                  AppTextField(
                    controller: email,
                    label: 'Work email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        RegExp(r'^\S+@\S+\.\S+$').hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Enter a valid work email',
                  ),
                  AppTextField(
                    controller: password,
                    label: 'Initial password (6 digits)',
                    obscure: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        v != null &&
                            v.length == 6 &&
                            RegExp(r'^[0-9]{6}$').hasMatch(v)
                        ? null
                        : 'Enter exactly 6 digits',
                  ),
                ],
                AppTextField(
                  controller: designation,
                  label: 'Designation',
                  validator: (_) => null,
                ),
                AppTextField(
                  controller: salary,
                  label: 'Salary',
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') != null && double.parse(v!) >= 0
                      ? null
                      : 'Enter a non-negative salary',
                ),
                ChoiceField(
                  label: 'Role',
                  items: [
                    const Choice('employee', 'Employee'),
                    Choice('manager', 'Manager'),
                    Choice('hr', 'HR'),
                    if (context.read<AuthCubit>().state.employee?.role ==
                        'super_admin')
                      const Choice('super_admin', 'Super admin'),
                  ],
                  value: role,
                  required: true,
                  onChanged: (v) => role = v!,
                ),
                ChoiceField(
                  label: 'Department',
                  items: departments,
                  value: department,
                  onChanged: (v) => department = v,
                ),
                TextButton.icon(
                  onPressed: state.busy ? null : addDepartment,
                  icon: Icon(Icons.add_rounded, size: 18.r),
                  label: const AppText('Add department'),
                ),
                SizedBox(height: 12.h),
                ChoiceField(
                  label: 'Branch',
                  items: widget.directory.branches,
                  value: branch,
                  onChanged: (v) => branch = v,
                ),
                ChoiceField(
                  label: 'Manager',
                  items: widget.directory.managers
                      .where((m) => m.id != widget.staff?.id)
                      .toList(),
                  value: manager,
                  onChanged: (v) => manager = v,
                ),
                ChoiceField(
                  label: 'Shift',
                  items: widget.directory.shifts,
                  value: shift,
                  onChanged: (v) => shift = v,
                ),
                if (widget.staff != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText('Employee active'),
                    value: active,
                    onChanged: (v) => setState(() => active = v),
                  ),
                if (state.status == LoadStatus.failure &&
                    state.message != null) ...[
                  AppText(
                    state.message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],
                AppButton(
                  label: 'Save employee',
                  loading: state.busy,
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    final data = <String, Object?>{
                      'full_name': name.text.trim(),
                      'role': role,
                      'salary': double.parse(salary.text),
                      'designation': designation.text.trim(),
                      'department_id': department,
                      'branch_id': branch,
                      'manager_id': manager,
                      'shift_id': shift,
                      if (widget.staff != null) 'is_active': active,
                      if (widget.staff == null) ...{
                        'email': email.text.trim(),
                        'password': password.text,
                      },
                    };
                    final ok = await context.read<EmployeeDetailCubit>().save(
                      widget.staff?.id,
                      data,
                    );
                    if (ok) password.clear();
                    if (ok &&
                        context.mounted &&
                        ModalRoute.of(context)?.isCurrent == true) {
                      Navigator.pop(context);
                    }
                  },
                ),
                if (widget.staff != null) ...[
                  SizedBox(height: 28.h),
                  AppText(
                    'Kiosk PIN',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const AppText(
                    'Set a new PIN to unlock or reset access. Existing PINs cannot be read.',
                  ),
                  SizedBox(height: 12.h),
                  AppTextField(
                    controller: pin,
                    label: 'New PIN (6–12 digits)',
                    obscure: true,
                    keyboardType: TextInputType.number,
                  ),
                  AppButton(
                    label: 'Set / reset PIN',
                    loading: state.busy,
                    onPressed: () {
                      if (!RegExp(r'^[0-9]{6,12}$').hasMatch(pin.text)) {
                        toast(context, 'Enter 6–12 digits.');
                        return;
                      }
                      final secret = pin.text;
                      pin.clear();
                      context.read<EmployeeDetailCubit>().pin(
                        widget.staff!.id,
                        secret,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
