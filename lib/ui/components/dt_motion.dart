import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../theme/dt_theme.dart';

class DtMotion {
  const DtMotion._();

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration duration(
    BuildContext context, [
    Duration duration = DtMotionTokens.page,
  ]) => reduced(context) ? Duration.zero : duration;
}

/// A small, reusable touch surface that gives every native control the same
/// opacity-only press response. Reduced-motion mode keeps the hit target and feedback,
/// with no transform or bounce.
class DtPressable extends StatelessWidget {
  const DtPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedOpacity = 0.68,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedOpacity;
  final bool haptic;
  final HitTestBehavior behavior;
  final String? semanticLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final reduced = DtMotion.reduced(context);
    return FTappable.static(
      style: (s) => s.copyWith(
        pressedEnterDuration: Duration.zero,
        pressedExitDuration: Duration.zero,
      ),
      semanticsLabel: semanticLabel,
      behavior: behavior,
      onPress: enabled && onTap != null
          ? () {
              if (haptic) HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      onLongPress: enabled && onLongPress != null
          ? () {
              if (haptic) HapticFeedback.mediumImpact();
              onLongPress!();
            }
          : null,
      builder: (context, states, child) => AnimatedOpacity(
        opacity: states.contains(WidgetState.pressed) ? pressedOpacity : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 90),
        child: child,
      ),
      child: child,
    );
  }
}

/// Lists stay still. Only route changes and explicit state changes animate.
class DtStagger extends StatelessWidget {
  const DtStagger({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 0,
  });
  final Widget child;
  final int index;
  final double offset;
  @override
  Widget build(BuildContext context) => child;
}
