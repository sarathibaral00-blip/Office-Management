import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_text.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../notifications/domain/entities/notifications.dart';
import '../../../notifications/presentation/bloc/notifications_cubit.dart';

/// Presentation-only controls reusing the existing Auth and Inbox Cubits.
class DashboardActions extends StatelessWidget {
  const DashboardActions({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Open menu',
        color: Colors.white,
        icon: Icon(Icons.menu_rounded, size: 26.r),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      SizedBox(width: 4.w),
      Expanded(
        child: AppText(
          'Pride People',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      BlocProvider(
        create: (_) => di<NotificationsCubit>()..load(),
        child: BlocBuilder<NotificationsCubit, FlowState<InboxData>>(
          builder: (context, state) {
            final unread = state.data?.unread ?? 0;
            return Badge(
              isLabelVisible: unread > 0,
              label: AppText(
                unread > 99 ? '99+' : '$unread',
                style: TextStyle(fontSize: 10.sp, color: Colors.white),
              ),
              child: IconButton(
                tooltip: 'Notifications',
                color: Colors.white,
                icon: Icon(Icons.notifications_outlined, size: 24.r),
                onPressed: () async {
                  await context.push('/notifications');
                  if (context.mounted) {
                    context.read<NotificationsCubit>().load();
                  }
                },
              ),
            );
          },
        ),
      ),
      SizedBox(width: 4.w),
      IconButton(
        tooltip: 'Display preferences',
        color: Colors.white,
        icon: Icon(Icons.translate_rounded, size: 24.r),
        onPressed: () => context.push('/preferences'),
      ),
    ],
  );
}
