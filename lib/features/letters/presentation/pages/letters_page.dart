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
import '../../domain/entities/letters.dart';
import '../bloc/letters_cubit.dart';

class LettersPage extends StatefulWidget {
  const LettersPage({super.key});
  @override
  State<LettersPage> createState() => _LettersPageState();
}

class _LettersPageState extends State<LettersPage> {
  String? employee;
  String kind = 'appointment';
  final purpose = TextEditingController();
  @override
  void initState() {
    super.initState();
    context.read<LettersCubit>().load();
  }

  @override
  void dispose() {
    purpose.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<LettersCubit, FlowState<LetterData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      final c = context.read<LettersCubit>();
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Employee letters'),
            SizedBox(height: 8.h),
            const AppText(
              'Issue a recorded letter using the approved company logo and signature.',
            ),
            SizedBox(height: 20.h),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Letters unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: c.load,
              )
            else ...[
              AppCard(
                child: Column(
                  children: [
                    ChoiceField(
                      label: 'Employee',
                      items: data.employees,
                      value: employee,
                      required: true,
                      onChanged: (v) => employee = v,
                    ),
                    ChoiceField(
                      label: 'Template',
                      items: const [
                        Choice('appointment', 'Appointment'),
                        Choice('confirmation', 'Confirmation'),
                        Choice('experience', 'Experience'),
                        Choice('salary_certificate', 'Salary certificate'),
                        Choice('noc', 'NOC'),
                      ],
                      value: kind,
                      required: true,
                      onChanged: (v) => kind = v!,
                    ),
                    AppTextField(
                      controller: purpose,
                      label: 'Purpose / approved dates and terms',
                    ),
                    AppButton(
                      label: 'Issue & download PDF',
                      loading: state.busy,
                      onPressed: () {
                        if (employee == null ||
                            purpose.text.trim().length < 3) {
                          toast(
                            context,
                            'Choose an employee and enter the purpose or terms.',
                          );
                          return;
                        }
                        c.issue(employee!, kind, purpose.text.trim());
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              ...data.letters.map(
                (l) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          l.name,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        AppText(
                          '${l.kind.replaceAll('_', ' ')} · ${DateFormat('dd MMM yyyy').format(l.date.toLocal())}',
                        ),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: state.busy
                                  ? null
                                  : () => c.export(l.id, false),
                              child: const AppText('Download PDF'),
                            ),
                            TextButton(
                              onPressed: state.busy
                                  ? null
                                  : () => c.export(l.id, true),
                              child: const AppText('Share PDF'),
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
