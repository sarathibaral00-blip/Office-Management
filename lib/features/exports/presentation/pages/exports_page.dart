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
import '../../domain/entities/exports.dart';
import '../bloc/exports_cubit.dart';

class ExportsPage extends StatefulWidget {
  const ExportsPage({super.key});
  @override
  State<ExportsPage> createState() => _ExportsPageState();
}

class _ExportsPageState extends State<ExportsPage> {
  String kind = 'attendance', format = 'xlsx';
  String? department, branch;
  DateTime start = DateTime(DateTime.now().year, DateTime.now().month),
      end = DateTime.now();
  @override
  void initState() {
    super.initState();
    context.read<ExportsCubit>().load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ExportsCubit, FlowState<ExportOptions>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      final c = context.read<ExportsCubit>();
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Reports to go'),
            SizedBox(height: 8.h),
            const AppText(
              'Export your permitted attendance, leave and payroll data. Access is checked on the server.',
            ),
            SizedBox(height: 20.h),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Export options unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: c.load,
              )
            else
              AppCard(
                child: Column(
                  children: [
                    ChoiceField(
                      label: 'Report',
                      items: const [
                        Choice('attendance', 'Attendance'),
                        Choice('leave', 'Leave'),
                        Choice('payroll', 'Payroll'),
                      ],
                      value: kind,
                      required: true,
                      onChanged: (v) => setState(() => kind = v!),
                    ),
                    ChoiceField(
                      label: 'Format',
                      items: const [
                        Choice('xlsx', 'Excel (.xlsx)'),
                        Choice('csv', 'CSV'),
                        Choice('pdf', 'PDF'),
                      ],
                      value: format,
                      required: true,
                      onChanged: (v) => setState(() => format = v!),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          initialDateRange: DateTimeRange(
                            start: start,
                            end: end,
                          ),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2200),
                        );
                        if (range != null) {
                          setState(() {
                            start = range.start;
                            end = range.end;
                          });
                        }
                      },
                      icon: Icon(Icons.calendar_month, size: 20.r),
                      label: AppText(
                        '${DateFormat('dd MMM yyyy').format(start)} – ${DateFormat('dd MMM yyyy').format(end)}',
                      ),
                    ),
                    ChoiceField(
                      label: 'Department',
                      items: data.departments,
                      value: department,
                      onChanged: (v) => department = v,
                    ),
                    ChoiceField(
                      label: 'Branch',
                      items: data.branches,
                      value: branch,
                      onChanged: (v) => branch = v,
                    ),
                    AppButton(
                      label: 'Download report',
                      loading: state.busy,
                      onPressed: () => c.export(
                        kind,
                        start,
                        end,
                        department,
                        branch,
                        format,
                        false,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    AppButton(
                      label: 'Share report',
                      loading: state.busy,
                      onPressed: () => c.export(
                        kind,
                        start,
                        end,
                        department,
                        branch,
                        format,
                        true,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    AppText(
                      'CSV protects formula-like cells. Excel preserves text and numeric cells. PDFs preserve the rendered layout.',
                      style: TextStyle(fontSize: 11.sp),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
