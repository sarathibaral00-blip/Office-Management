import 'package:flutter/services.dart';
import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.gradient,
    this.height,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Gradient? gradient;
  final double? height;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(14.r),
    ),
    child: SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        style: gradient == null
            ? null
            : FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.black.withValues(alpha: .15),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: .75),
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox(
                height: 20.r,
                width: 20.r,
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  color: gradient == null ? null : Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20.r),
                    SizedBox(width: 8.w),
                  ],
                  Flexible(child: AppText(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    ),
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLength,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
    this.enabled = true,
    this.minHeight,
  });
  final Widget? prefixIcon, suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final double? minHeight;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 16.h),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: autofillHints,
      onChanged: onChanged,
      obscureText: obscure,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      validator:
          validator ??
          (v) => v == null || v.trim().isEmpty ? 'Enter $label' : null,
      decoration: InputDecoration(
        labelText: translate(context, label),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        constraints: minHeight == null
            ? null
            : BoxConstraints(minHeight: minHeight!),
      ),
      style: TextStyle(fontSize: 15.sp),
    ),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(_CompactSurface.active(context) ? 16.r : 20.r),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(
          alpha: _CompactSurface.active(context) ? .55 : 1,
        ),
        width: 1.w,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .03),
          blurRadius: 16.r,
          offset: Offset(0, 4.h),
        ),
      ],
    ),
    child: child,
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 14.r),
          SizedBox(width: 5.w),
        ],
        Flexible(
          child: AppText(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });
  final String title, message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(24.r),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 42.r,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(height: 12.h),
        AppText(
          title,
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        AppText(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const AppText('Try again')),
      ],
    ),
  );
}

class Loader extends StatefulWidget {
  const Loader({super.key});
  @override
  State<Loader> createState() => _LoaderState();
}

class _LoaderState extends State<Loader> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .3, end: .8).animate(controller),
    child: Column(
      children: List.generate(
        3,
        (i) => Container(
          height: 88.h,
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
      ),
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 680.w),
      child: SingleChildScrollView(padding: EdgeInsets.all(20.r), child: child),
    ),
  );
}

void toast(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: AppText(message)));

/// A shared visual system for secondary screens, isolated from Today and auth.
class CompactPageBody extends StatelessWidget {
  const CompactPageBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(
        color: colors.outlineVariant.withValues(alpha: .65),
      ),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 14.h,
          ),
          enabledBorder: border,
          border: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: colors.primary, width: 1.5.w),
          ),
          labelStyle: TextStyle(
            fontSize: 13.sp,
            color: colors.onSurfaceVariant,
          ),
        ),
        listTileTheme: ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
          minVerticalPadding: 8.h,
          horizontalTitleGap: 12.w,
          titleTextStyle: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
          subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12.sp,
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: Size(48.w, 48.h),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
        ),
      ),
      child: _CompactSurface(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760.w),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 28.h),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSurface extends InheritedWidget {
  const _CompactSurface({required super.child});
  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CompactSurface>() != null;
  @override
  bool updateShouldNotify(_CompactSurface oldWidget) => false;
}

class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 4.w,
        height: 24.h,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(4.r),
        ),
      ),
      SizedBox(width: 10.w),
      Expanded(
        child: AppText(
          title,
          style: TextStyle(
            fontSize: 22.sp,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.4.sp,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ],
  );
}

/// Equal-width tiles with intrinsic row heights, including large text support.
class ResponsiveTiles extends StatelessWidget {
  const ResponsiveTiles({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final columns = largeText ? 1 : (constraints.maxWidth >= 560.w ? 3 : 2);
      final gap = 12.w;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Column(
        children: [
          for (var start = 0; start < children.length; start += columns)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var index = start;
                      index < children.length && index < start + columns;
                      index++
                    ) ...[
                      if (index > start) SizedBox(width: gap),
                      SizedBox(width: width, child: children[index]),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
