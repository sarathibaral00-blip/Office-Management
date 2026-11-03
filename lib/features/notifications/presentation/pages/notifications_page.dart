import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/notifications.dart';
import '../bloc/notifications_cubit.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<NotificationsCubit, FlowState<InboxData>>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) {
      final data = state.data;
      return CompactPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title: 'Your inbox'),
            SizedBox(height: 8.h),
            AppText('${data?.unread ?? 0} unread notifications'),
            TextButton(
              onPressed: state.busy
                  ? null
                  : () => context.read<NotificationsCubit>().read(null),
              child: const AppText('Mark all as read'),
            ),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Inbox unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: () => context.read<NotificationsCubit>().load(),
              )
            else ...[
              if (data.items.isEmpty)
                const EmptyState(
                  title: 'You’re all caught up',
                  message: 'Updates and workday reminders will appear here.',
                ),
              ...data.items.map(
                (n) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                n.title,
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: n.read
                                      ? FontWeight.w500
                                      : FontWeight.w800,
                                ),
                              ),
                            ),
                            if (!n.read)
                              Icon(
                                Icons.circle,
                                size: 8.r,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        AppText(n.body),
                        SizedBox(height: 8.h),
                        AppText(
                          DateFormat('dd MMM, HH:mm').format(n.date.toLocal()),
                          style: TextStyle(fontSize: 11.sp),
                        ),
                        Wrap(
                          children: [
                            if (!n.read)
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => context
                                          .read<NotificationsCubit>()
                                          .read(n.id),
                                child: const AppText('Mark read'),
                              ),
                            TextButton(
                              onPressed: () => context.push(switch (n.kind) {
                                'notice' => '/notices',
                                'expense' => '/expenses',
                                'financing' => '/financing',
                                'leave' => '/leave',
                                'correction' => '/corrections',
                                _ => '/history',
                              }),
                              child: const AppText('View'),
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
