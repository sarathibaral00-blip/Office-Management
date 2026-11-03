import 'package:flutter/material.dart';

/// Wait for the overlay/closing animation to finish before callers dispose
/// controllers or navigate to another screen. showDialog's normal Future ends
/// at pop time, while its TextFields can still be mounted during the animation.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierDismissible: barrierDismissible,
    barrierColor:
        DialogTheme.of(context).barrierColor ??
        Theme.of(context).dialogTheme.barrierColor ??
        Colors.black54,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  final result = await navigator.push<T>(route);
  await route.completed;
  return result;
}

/// An async save may finish after Cancel/back or a session redirect. Never pop
/// the page underneath an already closing/removed dialog.
void dismissAppDialog<T>(BuildContext context, [T? result]) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
  Navigator.of(context).pop<T>(result);
}
