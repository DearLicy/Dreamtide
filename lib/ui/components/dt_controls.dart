import 'package:flutter/material.dart';

import '../theme/dt_theme.dart';
import 'dt_motion.dart';

enum DtSurfaceLevel { plain, raised, floating, tinted }

enum DtButtonVariant { primary, secondary, ghost, danger }

enum DtButtonStatus { idle, loading, success }

class DtIconButton extends StatelessWidget {
  const DtIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.badge,
    this.tooltip,
    this.soft = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? badge;
  final String? tooltip;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final button = DtPressable(
      onTap: onTap,
      semanticLabel: tooltip,
      child: AnimatedContainer(
        duration: DtMotion.duration(context, DtMotionTokens.fast),
        curve: DtMotionTokens.ease,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: soft
              ? (dark ? DtColors.darkElevated : DtColors.surfaceMuted)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: soft
              ? Border.all(
                  color: dark ? DtColors.darkLine : const Color(0xFFECE7DF),
                )
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: dark ? const Color(0xFFF0ECE4) : DtColors.ink,
            ),
            if (badge != null)
              Positioned(
                right: 5,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: DtColors.coral,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: dark ? DtColors.darkSurface : DtColors.surface,
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class DtSurface extends StatelessWidget {
  const DtSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.level = DtSurfaceLevel.raised,
    this.backgroundColor,
    this.borderRadius = DtRadii.card,
    this.showBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final DtSurfaceLevel level;
  final Color? backgroundColor;
  final double borderRadius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color =
        backgroundColor ??
        switch (level) {
          DtSurfaceLevel.tinted =>
            dark ? DtColors.darkElevated : DtColors.surfaceMuted,
          _ => dark ? DtColors.darkSurface : DtColors.surface,
        };
    final shadows = switch (level) {
      DtSurfaceLevel.plain => const <BoxShadow>[],
      DtSurfaceLevel.raised => DtShadows.soft(dark),
      DtSurfaceLevel.floating => DtShadows.floating(dark),
      DtSurfaceLevel.tinted => DtShadows.soft(dark),
    };
    final surface = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: dark ? DtColors.darkLine : const Color(0xFFECE7DF),
                width: 0.8,
              )
            : null,
        boxShadow: shadows,
      ),
      child: Padding(padding: padding, child: child),
    );
    final content = onTap == null && onLongPress == null
        ? surface
        : DtPressable(onTap: onTap, onLongPress: onLongPress, child: surface);
    return margin == null ? content : Padding(padding: margin!, child: content);
  }
}

class DtButton extends StatelessWidget {
  const DtButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DtButtonVariant.primary,
    this.status = DtButtonStatus.idle,
    this.ready = true,
    this.icon,
    this.loadingText,
    this.successText,
    this.fullWidth = true,
    this.compact = false,
    this.haptic = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final DtButtonVariant variant;
  final DtButtonStatus status;
  final bool ready;
  final IconData? icon;
  final String? loadingText;
  final String? successText;
  final bool fullWidth;
  final bool compact;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled =
        ready &&
        onPressed != null &&
        status != DtButtonStatus.loading &&
        status != DtButtonStatus.success;
    final (background, foreground, border) = _colors(dark, enabled);
    final height = compact ? 44.0 : 54.0;
    final displayText = switch (status) {
      DtButtonStatus.loading => loadingText ?? '正在处理…',
      DtButtonStatus.success => successText ?? '已完成',
      DtButtonStatus.idle => label,
    };
    final content = AnimatedContainer(
      duration: DtMotion.duration(context, DtMotionTokens.fast),
      curve: DtMotionTokens.ease,
      height: height,
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DtRadii.pill),
        border: border == null ? null : Border.all(color: border),
        boxShadow: enabled && variant == DtButtonVariant.primary
            ? DtShadows.primary(dark)
            : const <BoxShadow>[],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: DtMotion.duration(context, DtMotionTokens.fast),
          switchInCurve: DtMotionTokens.ease,
          switchOutCurve: DtMotionTokens.ease,
          child: Row(
            key: ValueKey('$status-$displayText'),
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (status == DtButtonStatus.loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else if (status == DtButtonStatus.success)
                Icon(Icons.check_rounded, size: 19, color: foreground)
              else if (icon != null)
                Icon(icon, size: 19, color: foreground),
              if (status != DtButtonStatus.idle || icon != null)
                const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return DtPressable(
      onTap: enabled ? onPressed : null,
      enabled: enabled,
      haptic: haptic,
      semanticLabel: displayText,
      child: content,
    );
  }

  (Color, Color, Color?) _colors(bool dark, bool enabled) {
    if (!enabled) {
      final muted = dark ? const Color(0xFF2A2722) : const Color(0xFFE6E1D8);
      final text = dark ? const Color(0xFF7F786E) : const Color(0xFF9A9389);
      return (muted, text, null);
    }
    return switch (variant) {
      DtButtonVariant.primary => (
        dark ? const Color(0xFFF5F0E7) : DtColors.ink,
        dark ? const Color(0xFF17140F) : Colors.white,
        null,
      ),
      DtButtonVariant.secondary => (
        dark ? DtColors.darkElevated : DtColors.surface,
        dark ? const Color(0xFFF0ECE4) : DtColors.ink,
        dark ? DtColors.darkLine : const Color(0xFFDDD7CE),
      ),
      DtButtonVariant.ghost => (
        Colors.transparent,
        dark ? const Color(0xFFF0ECE4) : DtColors.ink,
        null,
      ),
      DtButtonVariant.danger => (
        dark ? const Color(0xFFE58D84) : DtColors.coral,
        dark ? const Color(0xFF2A1210) : Colors.white,
        null,
      ),
    };
  }
}

class DtSegmentedControl extends StatelessWidget {
  const DtSegmentedControl({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = labels.length;
    final alignment = count <= 1
        ? Alignment.center
        : Alignment(-1 + (2 * index / (count - 1)), 0);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dark ? DtColors.darkElevated : DtColors.surfaceMuted,
        borderRadius: BorderRadius.circular(DtRadii.pill),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            alignment: alignment,
            duration: DtMotion.duration(context, DtMotionTokens.fast),
            curve: DtMotionTokens.ease,
            child: FractionallySizedBox(
              widthFactor: 1 / count,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFFF2ECE2) : DtColors.surface,
                  borderRadius: BorderRadius.circular(DtRadii.pill),
                  boxShadow: DtShadows.soft(dark),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: DtPressable(
                    onTap: () => onChanged(i),
                    semanticLabel: labels[i],
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: DtMotion.duration(
                          context,
                          DtMotionTokens.fast,
                        ),
                        curve: DtMotionTokens.ease,
                        style: TextStyle(
                          color: i == index
                              ? (dark ? const Color(0xFF17140F) : DtColors.ink)
                              : (dark
                                    ? const Color(0xFF9B9388)
                                    : DtColors.textSecondary),
                          fontSize: 13,
                          fontWeight: i == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        child: Text(labels[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class DtSettingRow extends StatelessWidget {
  const DtSettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DtPressable(
      onTap: onTap,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? DtColors.brand).withValues(
                  alpha: dark ? 0.18 : 0.1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? DtColors.brand, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: dark
                            ? const Color(0xFF9B9388)
                            : DtColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: dark
                      ? const Color(0xFF756E64)
                      : const Color(0xFFB7B0A6),
                ),
          ],
        ),
      ),
    );
  }
}

class DtPageHeader extends StatelessWidget {
  const DtPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(18, 10, 12, 10),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF9B9388)
                          : DtColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class DtEmptyState extends StatelessWidget {
  const DtEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: dark ? DtColors.darkElevated : DtColors.surfaceMuted,
                shape: BoxShape.circle,
                boxShadow: DtShadows.soft(dark),
              ),
              child: Icon(
                icon,
                color: dark ? const Color(0xFFF0ECE4) : DtColors.ink,
                size: 31,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.55,
                color: dark ? const Color(0xFF9B9388) : DtColors.textSecondary,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
