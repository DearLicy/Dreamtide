import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../theme/dt_theme.dart';

/// Sheets belong to the root navigator, covering the entire IM shell including
/// its navigation bar. The library owns dragging and dismissal.
Future<T?> showDtSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool isScrollControlled = false,
}) => showFSheet<T>(
  context: context,
  useRootNavigator: true,
  side: FLayout.btt,
  mainAxisMaxRatio: 0.94,
  builder: (context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    child: ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? DtColors.darkSurface
          : DtColors.surface,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDragHandle)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            builder(context),
          ],
        ),
      ),
    ),
  ),
);
