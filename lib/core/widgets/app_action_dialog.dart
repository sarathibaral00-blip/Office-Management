import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../localization/app_text.dart';
import 'app_dialog.dart';

/// Keeps validation, progress and server errors beside the action being taken.
Future<bool> showAppActionDialog({
  required BuildContext context,
  required String title,
  required String label,
  required Future<String?> Function(String value) onConfirm,
  String confirmLabel = 'Confirm',
  int minimumLength = 3,
}) async =>
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ActionDialog(
        title: title,
        label: label,
        confirmLabel: confirmLabel,
        minimumLength: minimumLength,
        onConfirm: onConfirm,
      ),
    ) ??
    false;

class _ActionDialog extends StatefulWidget {
  const _ActionDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.minimumLength,
    required this.onConfirm,
  });
  final String title, label, confirmLabel;
  final int minimumLength;
  final Future<String?> Function(String value) onConfirm;
  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  final form = GlobalKey<FormState>();
  final controller = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    String? failure;
    try {
      failure = await widget.onConfirm(controller.text.trim());
    } catch (_) {
      failure = 'Unable to complete this action. Please try again.';
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      error = failure;
    });
    if (failure == null) dismissAppDialog(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: AppText(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                enabled: !busy,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: translate(context, widget.label),
                  helperText: 'At least ${widget.minimumLength} characters',
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) =>
                    (value?.trim().length ?? 0) < widget.minimumLength
                    ? 'Enter at least ${widget.minimumLength} characters.'
                    : null,
              ),
              if (error != null) ...[
                SizedBox(height: 12.h),
                AppText(
                  error!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => dismissAppDialog(context, false),
          child: const AppText('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: busy
              ? SizedBox(
                  width: 18.r,
                  height: 18.r,
                  child: CircularProgressIndicator(strokeWidth: 2.w),
                )
              : AppText(widget.confirmLabel),
        ),
      ],
    ),
  );
}
