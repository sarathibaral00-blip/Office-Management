import 'package:hr_management/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/choice_field.dart';
import '../../../../core/domain/page_result.dart';
import '../../../../core/presentation/flow_state.dart';
import '../../domain/entities/preferences.dart';
import '../bloc/preferences_cubit.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocConsumer<PreferencesCubit, FlowState<UiPreferences>>(
        listener: (context, state) {
          if (state.message != null) toast(context, state.message!);
        },
        builder: (context, state) {
          final p = state.data ?? const UiPreferences();
          return CompactPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeading(title: 'Display preferences'),
                SizedBox(height: 20.h),
                AppCard(
                  child: Column(
                    children: [
                      ChoiceField(
                        label: 'Language',
                        items: const [
                          Choice('en', 'English'),
                          Choice('bn', 'বাংলা'),
                        ],
                        value: p.language,
                        required: true,
                        onChanged: state.busy
                            ? null
                            : (v) => context.read<PreferencesCubit>().save(
                                v!,
                                p.theme,
                              ),
                      ),
                      ChoiceField(
                        label: 'Appearance',
                        items: const [
                          Choice('system', 'System'),
                          Choice('light', 'Light'),
                          Choice('dark', 'Dark'),
                        ],
                        value: p.theme,
                        required: true,
                        onChanged: state.busy
                            ? null
                            : (v) => context.read<PreferencesCubit>().save(
                                p.language,
                                v!,
                              ),
                      ),
                      AppText(
                        'Preferences are stored only on this device.',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}
