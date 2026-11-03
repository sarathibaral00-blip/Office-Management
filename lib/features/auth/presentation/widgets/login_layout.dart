import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/localization/app_text.dart';

/// Full-window artwork; only the scrolling controls respect the system insets.
class LoginLayout extends StatelessWidget {
  const LoginLayout({super.key, required this.form});
  final Widget form;
  static const topColor = Color(0xFF7A1128);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final insets = MediaQuery.paddingOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboard = keyboardInset > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        resizeToAvoidBottomInset: false,
        backgroundColor: topColor,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = math.max(
              0.h,
              constraints.maxHeight - keyboardInset,
            );
            final bannerHeight =
                insets.top +
                math.min(
                  keyboard ? 64.h : 118.h,
                  availableHeight * (keyboard ? .12 : .18),
                );
            final logoSize = keyboard ? 60.r : 72.r;
            // The form's first item overlaps the banner edge while remaining
            // below the status bar. The image itself always starts at y = 0.
            final bannerVisibleHeight = math.max(
              0.h,
              bannerHeight - insets.top - logoSize * .5,
            );
            final showCartoon = !keyboard && !dark;
            final footerHeight = showCartoon
                ? constraints.maxWidth * 520 / 1080
                : 0.h;
            final reservedBottom = keyboard
                ? keyboardInset
                : showCartoon
                ? footerHeight
                : insets.bottom;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: dark ? colors.surface : const Color(0xFFFAF7F7),
                ),
                Positioned(
                  top: 0.h,
                  left: 0.w,
                  right: 0.w,
                  child: Container(height: insets.top + 2.h, color: topColor),
                ),
                Positioned(
                  top: 0.h,
                  left: 0.w,
                  right: 0.w,
                  child: ClipRect(
                    child: Image.asset(
                      AppAssets.loginTopBanner,
                      width: double.infinity,
                      height: bannerHeight,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.bottomCenter,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Positioned.fill(
                  bottom: reservedBottom,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      24.w + insets.left,
                      insets.top + bannerVisibleHeight,
                      24.w + insets.right,
                      20.h,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 420.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) => Opacity(
                                  opacity: value,
                                  child: Transform.scale(
                                    scale: .9 + value * .1,
                                    child: child,
                                  ),
                                ),
                                child: Container(
                                  width: logoSize,
                                  height: logoSize,
                                  padding: EdgeInsets.all(10.r),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF5C0A1A,
                                        ).withValues(alpha: .14),
                                        blurRadius: 24.r,
                                        offset: Offset(0, 7.h),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    AppAssets.logo,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'Pride People logo',
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 16.h),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 14.h * (1 - value)),
                                  child: child,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppText(
                                    'Welcome Back',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 26.sp,
                                      fontWeight: FontWeight.w800,
                                      color: dark
                                          ? colors.onSurface
                                          : const Color(0xFF1F1A1B),
                                      letterSpacing: -.6.sp,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  AppText(
                                    'Sign in to your office account',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      height: 1.4,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  SizedBox(height: 20.h),
                                  form,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (showCartoon)
                  Positioned(
                    bottom: 0.h,
                    left: 0.w,
                    right: 0.w,
                    child: Image.asset(
                      AppAssets.loginBottomBanner,
                      width: double.infinity,
                      height: footerHeight,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.bottomCenter,
                      excludeFromSemantics: true,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
