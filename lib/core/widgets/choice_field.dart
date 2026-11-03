import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../domain/page_result.dart';

class ChoiceField extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.required = false,
  });
  final String label;
  final List<Choice> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool required;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 16.h),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: items.any((i) => i.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: translate(context, label)),
      items: [
        if (!required)
          const DropdownMenuItem(value: '', child: AppText('None / All')),
        ...items.map(
          (i) => DropdownMenuItem(
            value: i.id,
            child: AppText(
              i.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
        ),
      ],
      onChanged: onChanged == null
          ? null
          : (v) => onChanged!(v == '' ? null : v),
      validator: required
          ? (v) => v == null || v.isEmpty ? 'Choose $label' : null
          : null,
    ),
  );
}
