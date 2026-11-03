import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.onMonth,
    required this.onDay,
    required this.marked,
  });
  final DateTime month;
  final ValueChanged<DateTime> onMonth, onDay;
  final bool Function(DateTime) marked;
  @override
  Widget build(BuildContext context) {
    final start = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: Icon(Icons.chevron_left, size: 24.r),
            ),
            Expanded(
              child: AppText(
                DateFormat('MMMM yyyy').format(month),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: Icon(Icons.chevron_right, size: 24.r),
            ),
          ],
        ),
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map(
                (s) => Expanded(
                  child: Center(
                    child: AppText(s, style: TextStyle(fontSize: 12.sp)),
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: 12.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days + start.weekday - 1,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4.h,
            crossAxisSpacing: 4.w,
          ),
          itemBuilder: (context, i) {
            final n = i - start.weekday + 2;
            if (n < 1) return const SizedBox.shrink();
            final d = DateTime(month.year, month.month, n);
            return InkWell(
              borderRadius: BorderRadius.circular(10.r),
              onTap: () => onDay(d),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: marked(d)
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: AppText(
                  '$n',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: marked(d)
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
