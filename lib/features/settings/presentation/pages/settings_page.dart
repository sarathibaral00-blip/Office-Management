import '../../../../core/widgets/app_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/settings.dart';
import '../bloc/settings_cubit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final controllers = {
    for (final k in [
      'company_name',
      'address',
      'registration_no',
      'currency',
      'late_fee',
      'free_lates',
      'overtime_multiplier',
      'max_daily_overtime',
    ])
      k: TextEditingController(),
  };
  bool initialized = false, deduct = true;
  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().load();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> shift([ShiftSchedule? shift]) async {
    final name = TextEditingController(text: shift?.name),
        start = TextEditingController(text: shift?.start ?? '09:00'),
        end = TextEditingController(text: shift?.end ?? '18:00'),
        grace = TextEditingController(text: (shift?.grace ?? 15).toString());
    final days = {
      ...shift?.days ?? [0, 1, 2, 3, 4],
    };
    bool def = shift?.defaultShift ?? false;
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const AppText('Shift schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: name, label: 'Name'),
                AppTextField(controller: start, label: 'Start (HH:mm)'),
                AppTextField(controller: end, label: 'End (HH:mm)'),
                AppTextField(
                  controller: grace,
                  label: 'Grace minutes',
                  keyboardType: TextInputType.number,
                ),
                Wrap(
                  spacing: 4.w,
                  children: List.generate(7, (i) {
                    final day = (i + 1) % 7;
                    return FilterChip(
                      label: AppText(
                        ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day],
                        style: TextStyle(fontSize: 11.sp),
                      ),
                      selected: days.contains(day),
                      onSelected: (v) => set(() {
                        if (v) {
                          days.add(day);
                        } else {
                          days.remove(day);
                        }
                      }),
                    );
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const AppText('Default shift'),
                  value: def,
                  onChanged: (v) => set(() => def = v),
                ),
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
                final g = int.tryParse(grace.text);
                if (g == null ||
                    g < 0 ||
                    days.isEmpty ||
                    name.text.trim().isEmpty ||
                    !RegExp(
                      r'^([01][0-9]|2[0-3]):[0-5][0-9]$',
                    ).hasMatch(start.text) ||
                    !RegExp(
                      r'^([01][0-9]|2[0-3]):[0-5][0-9]$',
                    ).hasMatch(end.text)) {
                  toast(
                    ctx,
                    'Enter a shift name, valid HH:mm times, non-negative grace minutes and at least one working day.',
                  );
                  return;
                }
                final cubit = context.read<SettingsCubit>();
                await cubit.shift(shift?.id, {
                  'p_name': name.text.trim(),
                  'p_start': start.text,
                  'p_end': end.text,
                  'p_grace': g,
                  'p_days': days.toList(),
                  'p_default': def,
                });
                if (ctx.mounted && cubit.state.status == LoadStatus.success) {
                  dismissAppDialog(ctx);
                }
              },
              child: const AppText('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    start.dispose();
    end.dispose();
    grace.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SettingsCubit, FlowState<SettingsData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
      final values = state.data?.company?.values;
      if (values != null && !initialized) {
        for (final f in controllers.entries) {
          f.value.text = values[f.key]?.toString() ?? '';
        }
        deduct = values['deduct_absence'] == true;
        initialized = true;
      }
    },
    builder: (context, state) {
      final data = state.data;
      final c = context.read<SettingsCubit>();
      final superAdmin =
          context.watch<AuthCubit>().state.employee?.role == 'super_admin';
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Company settings'),
            SizedBox(height: 20.h),
            if (state.status == LoadStatus.loading && data == null)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Settings unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: () => c.load(),
              )
            else ...[
              if (data.company != null)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Company profile & pay policy',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      ...controllers.entries.map(
                        (f) => AppTextField(
                          controller: f.value,
                          label: f.key.replaceAll('_', ' '),
                          keyboardType:
                              [
                                'late_fee',
                                'free_lates',
                                'overtime_multiplier',
                                'max_daily_overtime',
                              ].contains(f.key)
                              ? TextInputType.number
                              : TextInputType.text,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const AppText('Deduct unpaid absence'),
                        value: deduct,
                        onChanged: (v) => setState(() => deduct = v),
                      ),
                      AppButton(
                        label: 'Save company policy',
                        loading: state.busy,
                        onPressed: () {
                          final values = <String, Object?>{
                            'deduct_absence': deduct,
                          };
                          for (final f in controllers.entries) {
                            if ([
                              'late_fee',
                              'free_lates',
                              'overtime_multiplier',
                              'max_daily_overtime',
                            ].contains(f.key)) {
                              final n = num.tryParse(f.value.text);
                              if (n == null || !n.isFinite || n < 0) {
                                toast(context, 'Enter valid policy numbers.');
                                return;
                              }
                              values[f.key] = n;
                            } else {
                              values[f.key] = f.value.text.trim();
                            }
                          }
                          c.company(values);
                        },
                      ),
                      SizedBox(height: 12.h),
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: state.busy
                                ? null
                                : () => c.asset('logo'),
                            child: const AppText('Upload company logo'),
                          ),
                          TextButton(
                            onPressed: state.busy
                                ? null
                                : () => c.asset('signature'),
                            child: const AppText('Upload authorized signature'),
                          ),
                        ],
                      ),
                      AppText(
                        'Assets: ${data.company!.values['logo_path'] == null ? 'logo missing' : 'logo ready'} · ${data.company!.values['signature_path'] == null ? 'signature missing' : 'signature ready'}',
                        style: TextStyle(fontSize: 11.sp),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 20.h),
              AppText(
                'Shifts & working days',
                style: TextStyle(fontSize: 21.sp, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: state.busy ? null : () => shift(),
                child: const AppText('Add shift'),
              ),
              ...data.shifts.map(
                (s) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: AppText(s.name),
                      subtitle: AppText(
                        '${s.start} – ${s.end} · ${s.grace} min grace${s.defaultShift ? ' · default' : ''}',
                      ),
                      trailing: Icon(Icons.edit_outlined, size: 20.r),
                      onTap: () => shift(s),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              AppText(
                'Roles & capabilities',
                style: TextStyle(fontSize: 21.sp, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => context.push('/employees'),
                child: const AppText('Manage employee role assignments'),
              ),
              AppText(
                'Super admin controls capabilities. A capability cannot expand a role’s security ceiling.',
                style: TextStyle(fontSize: 12.sp),
              ),
              ...data.permissions.map(
                (p) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: AppText(p.key, style: TextStyle(fontSize: 13.sp)),
                  subtitle: AppText(p.role),
                  value: p.enabled,
                  onChanged:
                      superAdmin && p.role != 'super_admin' && !state.busy
                      ? (v) => c.permission(p.role, p.key, v)
                      : null,
                ),
              ),
              SizedBox(height: 20.h),
              AppText(
                'Audit log',
                style: TextStyle(fontSize: 21.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8.h),
              ...data.audit.map(
                (a) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: AppCard(
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: AppText(
                        '${a['table_name']} · ${a['action']}',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      subtitle: AppText(
                        '${a['created_at']}\nActor: ${a['actor_id'] ?? 'system'}',
                        style: TextStyle(fontSize: 11.sp),
                      ),
                      children: [
                        SelectableText(
                          const JsonEncoder.withIndent('  ').convert(a),
                          style: TextStyle(fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (data.auditMore)
                AppButton(
                  label: 'Load more audit entries',
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
