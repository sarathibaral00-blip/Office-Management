import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../localization/app_text.dart';

/// The same navigation surface for the mobile drawer and desktop sidebar.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.name,
    required this.role,
    required this.employeeCode,
    required this.items,
    required this.currentPath,
    required this.onNavigate,
    required this.onSignOut,
    this.onClose,
  });
  final String name, role, employeeCode, currentPath;
  final List<(String, IconData, String)> items;
  final ValueChanged<String> onNavigate;
  final VoidCallback onSignOut;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'P'
        : parts
              .take(2)
              .map((part) => part.characters.first)
              .join()
              .toUpperCase();
    final roleLabel = switch (role) {
      'super_admin' => 'Super admin',
      'hr' => 'Human resources',
      'manager' => 'Manager',
      _ => 'Employee',
    };
    final groups = <(String, List<(String, IconData, String)>)>[
      (
        'WORKSPACE',
        items
            .where(
              (i) => ![
                '/employees',
                '/attendance-reports',
                '/attendance-support',
                '/networks',
                '/profile',
              ].contains(i.$3),
            )
            .toList(),
      ),
      (
        'MANAGEMENT',
        items
            .where(
              (i) => [
                '/employees',
                '/attendance-reports',
                '/attendance-support',
                '/networks',
              ].contains(i.$3),
            )
            .toList(),
      ),
      ('ACCOUNT', items.where((i) => i.$3 == '/profile').toList()),
    ];
    return Material(
      color: dark ? colors.surfaceContainerLow : const Color(0xFFFFFDFD),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 6.w, bottom: 12.h),
                    child: Row(
                      children: [
                        Container(
                          width: 30.r,
                          height: 30.r,
                          decoration: BoxDecoration(
                            color: const Color(0xFF800020),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.spa_rounded,
                            color: Colors.white,
                            size: 18.r,
                          ),
                        ),
                        SizedBox(width: 9.w),
                        Expanded(
                          child: AppText(
                            'Pride People',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.35.sp,
                            ),
                          ),
                        ),
                        if (onClose != null)
                          IconButton(
                            tooltip: 'Close menu',
                            onPressed: onClose,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18.r,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: dark
                          ? colors.surfaceContainer
                          : const Color(0xFFF7F2F3),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: .4),
                        width: 1.w,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36.r,
                          height: 36.r,
                          padding: EdgeInsets.all(5.r),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .1),
                            shape: BoxShape.circle,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              initials,
                              maxLines: 1,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                name,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              SizedBox(height: 3.h),
                              AppText(
                                roleLabel,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              if (employeeCode.isNotEmpty) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  employeeCode,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: colors.onSurfaceVariant.withValues(
                                      alpha: .8,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  for (final group in groups)
                    if (group.$2.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 6.h),
                        child: AppText(
                          group.$1,
                          style: TextStyle(
                            fontSize: 9.sp,
                            letterSpacing: 1.1.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: .7,
                            ),
                          ),
                        ),
                      ),
                      for (final item in group.$2)
                        Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: _SidebarItem(
                            label: item.$1,
                            icon: item.$2,
                            selected: currentPath == item.$3,
                            onTap: () => onNavigate(item.$3),
                          ),
                        ),
                    ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 10.h),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: .4),
                    width: 1.w,
                  ),
                ),
              ),
              child: _SidebarItem(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                selected: false,
                onTap: onSignOut,
                signOut: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.signOut = false,
  });
  final String label;
  final IconData icon;
  final bool selected, signOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? Colors.white
        : signOut
        ? colors.error
        : colors.onSurfaceVariant;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected
            ? const Color(0xFF800020)
            : signOut
            ? colors.error.withValues(alpha: .05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            constraints: BoxConstraints(minHeight: 44.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            child: Row(
              children: [
                Icon(icon, size: 19.r, color: foreground),
                SizedBox(width: 10.w),
                Expanded(
                  child: AppText(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      height: 1.3,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
                if (selected) ...[
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16.r,
                    color: Colors.white.withValues(alpha: .8),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
