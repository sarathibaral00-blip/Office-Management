import 'package:flutter/material.dart';
import '../../../../core/widgets/app_widgets.dart';

class AttendanceSourceBadge extends StatelessWidget {
  const AttendanceSourceBadge({super.key, required this.source});
  final String source;
  @override
  Widget build(BuildContext context) => source == 'app'
      ? const SizedBox.shrink()
      : StatusBadge(
          label: source[0].toUpperCase() + source.substring(1),
          color: Theme.of(context).colorScheme.primary,
          icon: switch (source) {
            'manual' => Icons.edit_note_rounded,
            'kiosk' => Icons.desktop_windows_outlined,
            _ => Icons.history_rounded,
          },
        );
}
