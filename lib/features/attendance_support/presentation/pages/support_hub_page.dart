import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/support_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_widgets.dart';

class SupportHubPage extends StatelessWidget {
  const SupportHubPage({super.key});
  @override
  Widget build(BuildContext context) => BlocBuilder<SupportCubit, SupportState>(
    builder: (context, state) => CompactPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(title: 'Keep every workday counted'),
          SizedBox(height: 12.h),
          const AppText(
            'Secure attendance options when an employee is without their phone.',
          ),
          SizedBox(height: 20.h),
          if (state.snapshot?.alerts.isNotEmpty == true) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(
                    label:
                        '${state.snapshot!.alerts.length} manual-attendance alerts',
                    color: const Color(0xFFED9B00),
                    icon: Icons.notifications_active_outlined,
                  ),
                  SizedBox(height: 8.h),
                  TextButton(
                    onPressed: () => context.push('/manual-attendance'),
                    child: const AppText('Review HR alerts'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
          ],
          ...[
            (
              Icons.edit_note_rounded,
              'Manual attendance',
              'Add or edit with a reason, manage the monthly limit and review HR alerts.',
              '/manual-attendance',
            ),
            (
              Icons.desktop_windows_outlined,
              'Office kiosks',
              'Approve this office terminal and set employee PINs.',
              '/kiosk-devices',
            ),
            (
              Icons.schedule_rounded,
              'Temporary approvals',
              'Approve this device for one employee for up to one day.',
              '/temporary-devices',
            ),
            (
              Icons.fact_check_outlined,
              'Non-app report',
              'Review manual, correction and kiosk attendance.',
              '/non-app-report',
            ),
          ].map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: AppCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14.r),
                  onTap: () async {
                    await context.push(item.$4);
                    if (context.mounted) {
                      context.read<SupportCubit>().load();
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        item.$1,
                        size: 30.r,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              item.$2,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            AppText(item.$3, style: TextStyle(fontSize: 13.sp)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 22.r),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
