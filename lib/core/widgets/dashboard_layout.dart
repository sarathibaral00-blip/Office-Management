import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../localization/app_text.dart';

/// Fixed image header and independently scrolling rounded body. The header is
/// a direct Column child: no overlap, slivers, paths or custom painting.
class DashboardLayout extends StatefulWidget {
  const DashboardLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.trailing,
    this.imageAsset = '',
    this.showImage = false,
    this.topBar,
    this.greetingTime,
    this.onTitleTap,
  });
  final String title, subtitle, imageAsset;
  final Widget child;
  final Widget trailing;
  final Widget? topBar;
  final DateTime? greetingTime;
  final VoidCallback? onTitleTap;
  final bool showImage;
  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  final scroll = ScrollController();
  double offset = 0;
  @override
  void initState() {
    super.initState();
    scroll.addListener(onScroll);
  }

  void onScroll() {
    final next = scroll.offset.clamp(0.0, 120.h);
    if ((next - offset).abs() > 0.5.h) setState(() => offset = next);
  }

  @override
  void dispose() {
    scroll.removeListener(onScroll);
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final headerColor = theme.brightness == Brightness.dark
        ? const Color(0xFF2B151C)
        : const Color(0xFF800020);
    final hasImage = widget.showImage && widget.imageAsset.isNotEmpty;
    final top = MediaQuery.paddingOf(context).top;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final max = 184.h * scale, min = 172.h * scale;
    final height = max - (max - min) * (offset / 120.h).clamp(0.0, 1.0);
    final hour = (widget.greetingTime ?? DateTime.now()).hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: ColoredBox(
        color: headerColor,
        child: Column(
          children: [
            AnimatedContainer(
              height: height + top,
              width: double.infinity,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: const Color(0xFF800020),
                image: hasImage
                    ? DecorationImage(
                        image: AssetImage(widget.imageAsset),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              padding: EdgeInsets.only(top: top),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 680.w),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 8.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.topBar != null) widget.topBar!,
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                widget.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 136.w),
                              child: widget.trailing,
                            ),
                          ],
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: widget.onTitleTap,
                          borderRadius: BorderRadius.circular(8.r),
                          child: Tooltip(
                            message:
                                '${translate(context, greeting)}, ${widget.title}',
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${translate(context, greeting)}, ',
                                  ),
                                  TextSpan(
                                    text: widget.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18.sp,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? colors.surface
                      : Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16.r),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  controller: scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 680.w),
                      child: Padding(
                        padding: EdgeInsets.all(20.r),
                        child: widget.child,
                      ),
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
}
