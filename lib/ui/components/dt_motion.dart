import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
/// 0.98 press response. Reduced-motion mode keeps the hit target and feedback,
/// but removes the transform.
class DtPressable extends StatefulWidget {
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
  State<DtPressable> createState() => _DtPressableState();
}

class _DtPressableState extends State<DtPressable> {
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _tap() {
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  void _longPress() {
    if (widget.haptic) HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = DtMotion.reduced(context);
    return Semantics(
      button: _interactive,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: _interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Listener(
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: GestureDetector(
            behavior: widget.behavior,
            onTap: _interactive && widget.onTap != null ? _tap : null,
            onLongPress: _interactive && widget.onLongPress != null
                ? _longPress
                : null,
            child: AnimatedOpacity(
              opacity: _pressed && !reduced ? widget.pressedOpacity : 1,
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A restrained list entrance: opacity + 8–10px translate, with a maximum of
/// 30ms staggering for the first eight items. It only animates transform and
/// opacity, and becomes instant when reduced motion is enabled.
class DtStagger extends StatefulWidget {
  const DtStagger({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = DtMotionTokens.listOffset,
  });

  final Widget child;
  final int index;
  final double offset;

  @override
  State<DtStagger> createState() => _DtStaggerState();
}

class _DtStaggerState extends State<DtStagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DtMotionTokens.page,
  );
  Timer? _delayTimer;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DtMotion.reduced(context)) {
      _delayTimer?.cancel();
      _controller.value = 1;
    } else if (!_scheduled) {
      _schedule();
    }
  }

  void _schedule() {
    _scheduled = true;
    final delay = DtMotionTokens.staggerStep * math.min(widget.index, 8);
    _delayTimer = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = DtMotionTokens.ease.transform(_controller.value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}
