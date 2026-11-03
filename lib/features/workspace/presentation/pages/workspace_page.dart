import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AuthCubit>().state.employee?.isAdmin == true;
    final groups = <_WorkspaceGroup>[
      _WorkspaceGroup('My work', 'Everyday tools and updates', [
        _WorkspaceItem(
          'Dashboard',
          'Your day at a glance',
          Icons.space_dashboard_rounded,
          '/dashboards',
        ),
        _WorkspaceItem(
          'Leave & approvals',
          'Requests and balances',
          Icons.beach_access_rounded,
          '/leave',
        ),
        _WorkspaceItem(
          'Holiday calendar',
          'Upcoming days off',
          Icons.event_available_rounded,
          '/holidays',
        ),
        _WorkspaceItem(
          'Attendance corrections',
          'Review time records',
          Icons.edit_calendar_rounded,
          '/corrections',
        ),
        _WorkspaceItem(
          'Notice board',
          'Company announcements',
          Icons.campaign_rounded,
          '/notices',
        ),
        _WorkspaceItem(
          'Notifications',
          'Your latest updates',
          Icons.notifications_active_rounded,
          '/notifications',
        ),
      ]),
      _WorkspaceGroup('Pay & records', 'Private employee records', [
        _WorkspaceItem(
          'Payroll',
          'Payslips and pay details',
          Icons.account_balance_wallet_rounded,
          '/payroll',
        ),
        _WorkspaceItem(
          'Advances & loans',
          'Requests and repayments',
          Icons.payments_rounded,
          '/financing',
        ),
        _WorkspaceItem(
          'Expense claims',
          'Receipts and reimbursements',
          Icons.receipt_long_rounded,
          '/expenses',
        ),
        _WorkspaceItem(
          'My documents',
          'Secure personal files',
          Icons.folder_shared_rounded,
          '/documents',
        ),
        _WorkspaceItem(
          'Reports & exports',
          'Download your reports',
          Icons.file_download_rounded,
          '/exports',
        ),
      ]),
      if (admin)
        _WorkspaceGroup('People & management', 'Team tools for HR and admins', [
          _WorkspaceItem(
            'Employee directory',
            'People and assignments',
            Icons.groups_rounded,
            '/employees',
          ),
          _WorkspaceItem(
            'Attendance reports',
            'Team time and trends',
            Icons.query_stats_rounded,
            '/attendance-reports',
          ),
          _WorkspaceItem(
            'Attendance support',
            'Manual entries and devices',
            Icons.support_agent_rounded,
            '/attendance-support',
          ),
          _WorkspaceItem(
            'Office networks',
            'Approved check-in locations',
            Icons.wifi_tethering_rounded,
            '/networks',
          ),
          _WorkspaceItem(
            'Letters',
            'Prepare employee letters',
            Icons.description_rounded,
            '/letters',
          ),
          _WorkspaceItem(
            'Settings',
            'Company and shift setup',
            Icons.tune_rounded,
            '/settings',
          ),
        ]),
      _WorkspaceGroup('Account', 'Your profile and preferences', [
        _WorkspaceItem(
          'My profile',
          'Personal details and security',
          Icons.account_circle_rounded,
          '/profile',
        ),
        _WorkspaceItem(
          'Preferences',
          'Language and appearance',
          Icons.palette_outlined,
          '/preferences',
        ),
      ]),
    ];
    final colors = Theme.of(context).colorScheme;
    return CompactPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(title: 'Workspace'),
          SizedBox(height: 5.h),
          AppText(
            'Your work, in one place',
            style: TextStyle(fontSize: 14.sp, color: colors.onSurfaceVariant),
          ),
          SizedBox(height: 22.h),
          ...groups.map(
            (group) => Padding(
              padding: EdgeInsets.only(bottom: 22.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    group.title,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  AppText(
                    group.subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 11.h),
                  ResponsiveTiles(
                    children: group.items
                        .map(
                          (item) => _WorkspaceTile(
                            item: item,
                            onTap: () => context.push(item.route),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceGroup {
  const _WorkspaceGroup(this.title, this.subtitle, this.items);
  final String title, subtitle;
  final List<_WorkspaceItem> items;
}

class _WorkspaceItem {
  const _WorkspaceItem(this.title, this.subtitle, this.icon, this.route);
  final String title, subtitle, route;
  final IconData icon;
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({required this.item, required this.onTap});
  final _WorkspaceItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: dark ? colors.surfaceContainerLow : colors.surface,
      borderRadius: BorderRadius.circular(15.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.r),
        child: Container(
          constraints: BoxConstraints(minHeight: 108.h),
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: dark ? .75 : .55),
              width: 1.w,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34.r,
                    height: 34.r,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: dark ? .16 : .09),
                      borderRadius: BorderRadius.circular(11.r),
                    ),
                    child: Icon(item.icon, size: 19.r, color: colors.primary),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 15.r,
                    color: colors.onSurfaceVariant.withValues(alpha: .7),
                  ),
                ],
              ),
              SizedBox(height: 9.h),
              AppText(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              SizedBox(height: 3.h),
              AppText(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.sp,
                  height: 1.25,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
