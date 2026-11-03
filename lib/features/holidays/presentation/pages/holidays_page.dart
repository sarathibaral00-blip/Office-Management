import '../../../../core/widgets/app_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../../../core/widgets/month_calendar.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../../core/error/result.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/holidays.dart';
import '../bloc/holidays_cubit.dart';

class HolidaysPage extends StatefulWidget {
  const HolidaysPage({super.key});
  @override
  State<HolidaysPage> createState() => _HolidaysPageState();
}

class _HolidaysPageState extends State<HolidaysPage> {
  DateTime month = DateTime.now();
  @override
  void initState() {
    super.initState();
    context.read<HolidaysCubit>().load();
  }

  Future<void> edit(HolidayData data, [Holiday? holiday]) async {
    final name = TextEditingController(text: holiday?.name);
    DateTime day = holiday?.day ?? DateTime.now();
    String? branch = holiday?.branch;
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: AppText(holiday == null ? 'Add holiday' : 'Edit holiday'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: name, label: 'Holiday name'),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: day,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2200),
                    );
                    if (d != null && ctx.mounted) set(() => day = d);
                  },
                  child: AppText(DateFormat('dd MMM yyyy').format(day)),
                ),
                ChoiceField(
                  label: 'Branch (none means all)',
                  items: data.branches,
                  value: branch,
                  onChanged: (v) => branch = v,
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
                if (name.text.trim().length < 2) {
                  toast(
                    ctx,
                    'Enter at least 2 characters for the holiday name.',
                  );
                  return;
                }
                final ok = await context.read<HolidaysCubit>().save(
                  holiday?.id,
                  name.text.trim(),
                  day,
                  branch,
                  true,
                );
                if (ok && ctx.mounted) dismissAppDialog(ctx);
              },
              child: const AppText('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<HolidaysCubit, FlowState<HolidayData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      final admin = context.watch<AuthCubit>().state.employee?.isAdmin == true;
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Days to look forward to'),
            SizedBox(height: 20.h),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Calendar unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: () => context.read<HolidaysCubit>().load(),
              )
            else ...[
              if (admin)
                AppButton(
                  label: 'Add holiday',
                  loading: state.busy,
                  onPressed: () => edit(data),
                ),
              SizedBox(height: 16.h),
              AppCard(
                child: MonthCalendar(
                  month: month,
                  onMonth: (v) {
                    setState(() => month = v);
                    final c = context.read<HolidaysCubit>();
                    if (c.year != v.year) {
                      c.year = v.year;
                      c.load();
                    }
                  },
                  onDay: (d) {
                    final matches = data.holidays.where((h) => h.day == d);
                    toast(
                      context,
                      matches.isEmpty
                          ? 'No holiday on this day'
                          : matches.map((h) => h.name).join(', '),
                    );
                  },
                  marked: (d) => data.holidays.any((h) => h.day == d),
                ),
              ),
              SizedBox(height: 20.h),
              ...data.holidays
                  .where((h) => h.day.month == month.month)
                  .map(
                    (h) => Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              h.name,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            AppText(
                              '${DateFormat('dd MMM yyyy').format(h.day)} · ${h.branch == null ? 'All branches' : data.branches.where((b) => b.id == h.branch).firstOrNull?.label ?? 'Office'}',
                            ),
                            if (admin)
                              Wrap(
                                children: [
                                  TextButton(
                                    onPressed: state.busy
                                        ? null
                                        : () => edit(data, h),
                                    child: const AppText('Edit'),
                                  ),
                                  TextButton(
                                    onPressed: state.busy
                                        ? null
                                        : () async {
                                            final yes = await showAppDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const AppText(
                                                  'Archive holiday?',
                                                ),
                                                content: const AppText(
                                                  'The holiday will be hidden from active calendars. Its data will be kept.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        dismissAppDialog(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const AppText(
                                                      'Cancel',
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        dismissAppDialog(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const AppText(
                                                      'Archive',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (yes == true &&
                                                context.mounted) {
                                              context
                                                  .read<HolidaysCubit>()
                                                  .save(
                                                    h.id,
                                                    h.name,
                                                    h.day,
                                                    h.branch,
                                                    false,
                                                  );
                                            }
                                          },
                                    child: const AppText('Archive'),
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
