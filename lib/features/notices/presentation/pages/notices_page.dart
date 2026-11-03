import '../../../../core/widgets/app_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../../../core/error/result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/notices.dart';
import '../bloc/notices_cubit.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  @override
  void initState() {
    super.initState();
    context.read<NoticesCubit>().load();
  }

  Future<void> edit(NoticeData data, [Notice? notice]) async {
    final title = TextEditingController(text: notice?.title),
        body = TextEditingController(text: notice?.body);
    String? department = notice?.department;
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText(notice == null ? 'Share a notice' : 'Edit notice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: title, label: 'Title'),
              TextField(
                controller: body,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(label: AppText('Message')),
                style: TextStyle(fontSize: 14.sp),
              ),
              SizedBox(height: 16.h),
              ChoiceField(
                label: 'Department (none means everyone)',
                items: data.departments,
                value: department,
                onChanged: (v) => department = v,
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
              if (title.text.trim().length < 3 || body.text.trim().length < 3) {
                return;
              }
              final ok = await context.read<NoticesCubit>().save(
                notice?.id,
                title.text.trim(),
                body.text.trim(),
                department,
                true,
              );
              if (ok && ctx.mounted) dismissAppDialog(ctx);
            },
            child: const AppText('Publish'),
          ),
        ],
      ),
    );
    title.dispose();
    body.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<NoticesCubit, FlowState<NoticeData>>(
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
            PageHeading(title: 'In the know'),
            SizedBox(height: 8.h),
            if (data != null)
              StatusBadge(
                label: '${data.unread} unread',
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.mark_email_unread_outlined,
              ),
            SizedBox(height: 20.h),
            if (admin && data != null)
              AppButton(
                label: 'Create announcement',
                loading: state.busy,
                onPressed: () => edit(data),
              ),
            SizedBox(height: 16.h),
            if (state.status == LoadStatus.loading)
              const Loader()
            else if (data == null)
              EmptyState(
                title: 'Notices unavailable',
                message: state.message ?? 'Please retry.',
                onRetry: () => context.read<NoticesCubit>().load(),
              )
            else ...[
              if (data.notices.isEmpty)
                const EmptyState(
                  title: 'All quiet for now',
                  message: 'Company and department updates will appear here.',
                ),
              ...data.notices.map(
                (n) => Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
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
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (n.unread)
                              StatusBadge(
                                label: 'New',
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        AppText(
                          DateFormat('dd MMM yyyy').format(n.date.toLocal()),
                          style: TextStyle(fontSize: 12.sp),
                        ),
                        SizedBox(height: 16.h),
                        AppText(
                          n.body,
                          style: TextStyle(fontSize: 14.sp, height: 1.5),
                        ),
                        Wrap(
                          children: [
                            if (n.unread)
                              TextButton(
                                onPressed: () =>
                                    context.read<NoticesCubit>().read(n.id),
                                child: const AppText('Mark as read'),
                              ),
                            if (admin) ...[
                              TextButton(
                                onPressed: () => edit(data, n),
                                child: const AppText('Edit'),
                              ),
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => context.read<NoticesCubit>().save(
                                        n.id,
                                        n.title,
                                        n.body,
                                        n.department,
                                        false,
                                      ),
                                child: const AppText('Archive'),
                              ),
                            ],
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
