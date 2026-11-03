import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/fallback.dart';

class EmployeeField extends StatelessWidget {
  const EmployeeField({
    super.key,
    required this.employees,
    required this.value,
    required this.onChanged,
  });
  final List<FallbackEmployee> employees;
  final String? value;
  final ValueChanged<String?>? onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 16.h),
    child: DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Employee'),
      items: employees
          .map(
            (e) => DropdownMenuItem(
              value: e.id,
              child: AppText(
                '${e.code} · ${e.name}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Choose an employee' : null,
    ),
  );
}

class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.optional = false,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool optional;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 12.h),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final initial = value ?? now;
                final day = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2000),
                  lastDate: now.add(const Duration(days: 1)),
                );
                if (day == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(initial),
                );
                if (time != null) {
                  onChanged(
                    DateTime(
                      day.year,
                      day.month,
                      day.day,
                      time.hour,
                      time.minute,
                    ),
                  );
                }
              },
              child: AppText(
                value == null
                    ? 'Choose date and time'
                    : DateFormat('dd MMM yyyy, HH:mm').format(value!),
                style: TextStyle(fontSize: 13.sp),
              ),
            ),
          ),
          if (optional && value != null)
            IconButton(
              tooltip: 'Leave checkout open',
              onPressed: () => onChanged(null),
              icon: Icon(Icons.close, size: 18.r),
            ),
        ],
      ),
    ),
  );
}
