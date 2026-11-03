import '../../../../core/widgets/app_dialog.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/network.dart';
import '../bloc/network_cubit.dart';

class NetworksPage extends StatefulWidget {
  const NetworksPage({super.key});
  @override
  State<NetworksPage> createState() => _NetworksPageState();
}

class _NetworksPageState extends State<NetworksPage> {
  @override
  void initState() {
    super.initState();
    context.read<NetworkCubit>().load();
  }

  Future<void> edit({OfficeNetwork? network, bool current = false}) async {
    final cubit = context.read<NetworkCubit>();
    // Refresh first: a failed/stale list must not be mistaken for no branches.
    await cubit.load();
    if (!mounted || cubit.state.data == null) return;
    final ip = current ? await cubit.currentIp() : null;
    if (!mounted || (current && ip == null)) return;
    var branches = cubit.state.data?.branches ?? [];
    if (branches.isEmpty) {
      final created = await showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            BlocProvider.value(value: cubit, child: const _BranchSetup()),
      );
      if (!mounted || created != true) return;
      branches = cubit.state.data?.branches ?? [];
      if (branches.isEmpty) return;
    }
    if (!mounted) return;
    await showAppDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _NetworkEditor(network: network, ip: ip, branches: branches),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<NetworkCubit, NetworkState>(
    listener: (context, state) {
      if (state.message != null) toast(context, state.message!);
    },
    builder: (context, state) => CompactPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(title: 'Office networks'),
          SizedBox(height: 8.h),
          const AppText('Manage where your team can check in and out.'),
          SizedBox(height: 20.h),
          AppCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 28.r,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 12.w),
                    const Expanded(
                      child: AppText(
                        'Allow your office public IP or CIDR range. A WiFi name alone does not verify attendance.',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                AppButton(
                  label: 'Add my current IP',
                  icon: Icons.my_location_rounded,
                  onPressed: state.status == LoadStatus.loading || state.busy
                      ? null
                      : () => edit(current: true),
                ),
                TextButton.icon(
                  onPressed: state.status == LoadStatus.loading || state.busy
                      ? null
                      : () => edit(),
                  icon: Icon(Icons.add, size: 18.r),
                  label: const AppText('Add network manually'),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          if (state.status == LoadStatus.loading)
            const Loader()
          else if (state.data == null)
            EmptyState(
              title: 'Networks unavailable',
              message: state.message ?? 'Try again.',
              onRetry: () => context.read<NetworkCubit>().load(),
            )
          else if (state.data!.networks.isEmpty)
            const EmptyState(
              title: 'No office networks yet',
              message:
                  'Add a public IP and link it to a branch to enable attendance.',
            )
          else
            ...state.data!.networks.map(
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
                              n.label,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Switch(
                            value: n.active,
                            onChanged: state.busy
                                ? null
                                : (v) => context.read<NetworkCubit>().save(
                                    id: n.id,
                                    label: n.label,
                                    network: n.network,
                                    branchId: n.branchId,
                                    active: v,
                                  ),
                          ),
                        ],
                      ),
                      AppText(n.network, style: TextStyle(fontSize: 15.sp)),
                      SizedBox(height: 8.h),
                      AppText(
                        state.data!.branches
                                .where((b) => b.id == n.branchId)
                                .firstOrNull
                                ?.name ??
                            'Branch unavailable',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          StatusBadge(
                            label: n.active ? 'Active' : 'Inactive',
                            color: n.active
                                ? const Color(0xFF2E7D32)
                                : Colors.grey,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Edit network',
                            onPressed: () => edit(network: n),
                            icon: Icon(Icons.edit_outlined, size: 20.r),
                          ),
                          IconButton(
                            tooltip: 'Delete network',
                            onPressed: () async {
                              final yes = await showAppDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const AppText(
                                    'Delete office network?',
                                  ),
                                  content: AppText(
                                    'Employees on ${n.label} will no longer be able to check in or out.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          dismissAppDialog(ctx, false),
                                      child: const AppText('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          dismissAppDialog(ctx, true),
                                      child: const AppText('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (yes == true && context.mounted) {
                                context.read<NetworkCubit>().delete(n.id);
                              }
                            },
                            icon: Icon(Icons.delete_outline, size: 20.r),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _NetworkEditor extends StatefulWidget {
  const _NetworkEditor({this.network, this.ip, required this.branches});
  final OfficeNetwork? network;
  final String? ip;
  final List<Branch> branches;
  @override
  State<_NetworkEditor> createState() => _NetworkEditorState();
}

class _NetworkEditorState extends State<_NetworkEditor> {
  late final label = TextEditingController(text: widget.network?.label);
  late final network = TextEditingController(
    text: widget.network?.network ?? widget.ip,
  );
  late String branch = widget.network?.branchId ?? widget.branches.first.id;
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    label.dispose();
    network.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 440.w),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                widget.network == null
                    ? 'Add office network'
                    : 'Edit office network',
                style: TextStyle(fontSize: 21.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 20.h),
              AppTextField(controller: label, label: 'Network label'),
              AppTextField(controller: network, label: 'Public IP or CIDR'),
              DropdownButtonFormField<String>(
                initialValue: branch,
                isExpanded: true,
                decoration: const InputDecoration(label: AppText('Branch')),
                items: widget.branches
                    .map(
                      (b) =>
                          DropdownMenuItem(value: b.id, child: AppText(b.name)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) branch = v;
                },
              ),
              SizedBox(height: 20.h),
              BlocBuilder<NetworkCubit, NetworkState>(
                builder: (context, state) => Column(
                  children: [
                    if (state.status == LoadStatus.failure &&
                        state.message != null)
                      AppText(
                        state.message!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13.sp,
                        ),
                      ),
                    AppButton(
                      label: 'Save network',
                      loading: state.busy,
                      onPressed: () async {
                        if (!form.currentState!.validate()) return;
                        final saved = await context.read<NetworkCubit>().save(
                          id: widget.network?.id,
                          label: label.text.trim(),
                          network: network.text.trim(),
                          branchId: branch,
                          active: widget.network?.active ?? true,
                        );
                        if (saved && context.mounted) dismissAppDialog(context);
                      },
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => dismissAppDialog(context),
                child: const AppText('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BranchSetup extends StatefulWidget {
  const _BranchSetup();

  @override
  State<_BranchSetup> createState() => _BranchSetupState();
}

class _BranchSetupState extends State<_BranchSetup> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<NetworkCubit, NetworkState>(
    builder: (context, state) => PopScope(
      canPop: !state.busy,
      child: Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440.w),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.r),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Create your first branch',
                    style: TextStyle(
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  const AppText(
                    'Every office network belongs to a branch. Create one here, then save your detected IP on the next screen.',
                  ),
                  SizedBox(height: 20.h),
                  AppTextField(
                    controller: name,
                    label: 'Branch name',
                    validator: (value) =>
                        value == null ||
                            value.trim().isEmpty ||
                            value.trim().length > 100
                        ? 'Enter a branch name between 1 and 100 characters.'
                        : null,
                  ),
                  SizedBox(height: 8.h),
                  const AppText(
                    'New branches use the database default timezone (Asia/Dhaka).',
                  ),
                  SizedBox(height: 20.h),
                  if (state.status == LoadStatus.failure &&
                      state.message != null) ...[
                    AppText(
                      state.message!,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                  AppButton(
                    label: 'Create branch and continue',
                    loading: state.busy,
                    onPressed: () async {
                      if (!form.currentState!.validate()) return;
                      final created = await context
                          .read<NetworkCubit>()
                          .createBranch(name.text);
                      if (created && context.mounted) {
                        dismissAppDialog(context, true);
                      }
                    },
                  ),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => dismissAppDialog(context, false),
                    child: const AppText('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
