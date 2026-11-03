import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/app_text.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../domain/entities/payroll.dart';

Future<void> showSalaryStructureSheet({
  required BuildContext context,
  required PayrollData data,
  required Future<String?> Function(
    String employee,
    Map<String, Object?> values,
  )
  onSave,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  constraints: BoxConstraints(maxWidth: 720.w),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (_) => SalaryStructureSheet(data: data, onSave: onSave),
);

class SalaryStructureSheet extends StatefulWidget {
  const SalaryStructureSheet({
    super.key,
    required this.data,
    required this.onSave,
  });
  final PayrollData data;
  final Future<String?> Function(String employee, Map<String, Object?> values)
  onSave;

  @override
  State<SalaryStructureSheet> createState() => _SalaryStructureSheetState();
}

class _SalaryStructureSheetState extends State<SalaryStructureSheet> {
  static const amountKeys = ['basic', 'house_rent', 'medical', 'conveyance'];
  static const bankKeys = ['bank_name', 'account_name', 'account_number'];
  static const labels = {
    'basic': 'Basic salary',
    'house_rent': 'House rent',
    'medical': 'Medical',
    'conveyance': 'Conveyance',
    'bank_name': 'Bank name',
    'account_name': 'Account holder',
    'account_number': 'Account number',
  };
  final form = GlobalKey<FormState>();
  final fields = {
    for (final key in [...amountKeys, ...bankKeys])
      key: TextEditingController(text: amountKeys.contains(key) ? '0' : ''),
  };
  String? employee, error;
  bool busy = false;

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void selectEmployee(String? id) {
    setState(() {
      employee = id;
      error = null;
      final structure = widget.data.structures[id];
      for (final field in fields.entries) {
        field.value.text =
            structure?[field.key]?.toString() ??
            (amountKeys.contains(field.key) ? '0' : '');
      }
    });
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    final values = <String, Object?>{
      for (final key in amountKeys) key: double.parse(fields[key]!.text.trim()),
      for (final key in bankKeys) key: fields[key]!.text.trim(),
    };
    String? failure;
    try {
      failure = await widget.onSave(employee!, values);
    } catch (_) {
      failure = 'Unable to save salary structure. Please try again.';
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      error = failure;
    });
    if (failure == null && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  Widget field(String key) => TextFormField(
    controller: fields[key],
    enabled: !busy,
    style: TextStyle(fontSize: 13.sp),
    keyboardType: amountKeys.contains(key)
        ? const TextInputType.numberWithOptions(decimal: true)
        : key == 'account_number'
        ? TextInputType.text
        : TextInputType.name,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      labelText: translate(context, labels[key]!),
      labelStyle: TextStyle(fontSize: 12.sp),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .65),
        ),
      ),
      errorMaxLines: 2,
    ),
    onChanged: amountKeys.contains(key) ? (_) => setState(() {}) : null,
    validator: amountKeys.contains(key)
        ? (text) {
            final value = double.tryParse(text?.trim() ?? '');
            return value == null || !value.isFinite || value < 0
                ? 'Enter a valid amount'
                : null;
          }
        : null,
  );

  Widget fieldPairs(List<String> keys) => LayoutBuilder(
    builder: (context, constraints) {
      final single = MediaQuery.textScalerOf(context).scale(1) > 1.4;
      final columns = single ? 1 : 2;
      return Column(
        children: [
          for (var index = 0; index < keys.length; index += columns)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: field(keys[index])),
                  if (!single) ...[
                    SizedBox(width: 12.w),
                    Expanded(
                      child: index + 1 < keys.length
                          ? field(keys[index + 1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget section(String title, IconData icon) => Padding(
    padding: EdgeInsets.only(bottom: 14.h),
    child: Row(
      children: [
        Icon(icon, size: 18.r, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: 8.w),
        AppText(
          title,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = amountKeys.fold<double>(0, (sum, key) {
      final value = double.tryParse(fields[key]!.text.trim());
      return sum + (value != null && value.isFinite && value >= 0 ? value : 0);
    });
    return PopScope(
      canPop: !busy,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom) *
                .92,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 10.h, 12.w, 16.h),
                  child: Column(
                    children: [
                      Container(
                        width: 36.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 22.r,
                              color: colors.primary,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  'Salary structure',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 3.h),
                                AppText(
                                  'Monthly pay & bank details',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close salary structure',
                            onPressed: busy
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close_rounded, size: 20.r),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChoiceField(
                            label: 'Employee',
                            items: widget.data.employees,
                            value: employee,
                            required: true,
                            onChanged: busy ? null : selectEmployee,
                          ),
                          SizedBox(height: 4.h),
                          section('Salary components', Icons.payments_outlined),
                          fieldPairs(amountKeys),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.h,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .06),
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12.w,
                              runSpacing: 6.h,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      'Monthly total',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    AppText(
                                      'Before deductions',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  NumberFormat('#,##0.00').format(total),
                                  style: TextStyle(
                                    fontSize: 19.sp,
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20.h),
                          section(
                            'Bank details',
                            Icons.account_balance_outlined,
                          ),
                          fieldPairs(bankKeys),
                        ],
                      ),
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
                    child: AppText(
                      error!,
                      style: TextStyle(fontSize: 13.sp, color: colors.error),
                    ),
                  ),
                Container(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: .5),
                        width: 1.w,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(48.w, 46.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 12.h,
                            ),
                            textStyle: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const AppText('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: Size(48.w, 46.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 12.h,
                            ),
                            textStyle: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          onPressed: busy ? null : save,
                          child: busy
                              ? SizedBox(
                                  width: 18.r,
                                  height: 18.r,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.w,
                                  ),
                                )
                              : const AppText('Save structure'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
