import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/dt_motion.dart';
import '../theme/dt_theme.dart';
import 'app_drawer.dart';

class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: dark ? DtColors.darkBg : DtColors.mist,
      drawer: const AppDrawer(),
      body: ColoredBox(
        color: dark ? DtColors.darkBg : DtColors.canvas,
        child: _BranchTransition(
          index: navigationShell.currentIndex,
          child: navigationShell,
        ),
      ),
      bottomNavigationBar: _QqBottomBar(
        index: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _BranchTransition extends StatefulWidget {
  const _BranchTransition({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchTransition> createState() => _BranchTransitionState();
}

class _BranchTransitionState extends State<_BranchTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DtMotionTokens.page,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DtMotion.reduced(context)) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _BranchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !DtMotion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
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
          opacity: 0.9 + value * 0.1,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
    );
  }
}

class _QqBottomBar extends StatelessWidget {
  const _QqBottomBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '消息'),
    (Icons.people_outline_rounded, Icons.people_rounded, '联系人'),
    (Icons.blur_on_outlined, Icons.blur_on_rounded, '动态'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('root-bottom-bar'),
      decoration: BoxDecoration(
        color: (dark ? DtColors.darkSurface : DtColors.surface).withValues(
          alpha: 0.98,
        ),
        border: Border(
          top: BorderSide(
            color: dark ? DtColors.darkLine : const Color(0xFFE8E2DA),
            width: 0.7,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : const Color(0xFF211B15)).withValues(
              alpha: dark ? 0.34 : 0.07,
            ),
            blurRadius: 28,
            spreadRadius: -10,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: DtPressable(
                    onTap: () => onTap(i),
                    semanticLabel: _items[i].$3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: DtMotion.duration(
                            context,
                            DtMotionTokens.fast,
                          ),
                          curve: DtMotionTokens.ease,
                          width: 58,
                          height: 30,
                          decoration: BoxDecoration(
                            color: i == index
                                ? (dark
                                      ? const Color(0xFF2D291F)
                                      : DtColors.surfaceMuted)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: AnimatedSwitcher(
                            duration: DtMotion.duration(
                              context,
                              DtMotionTokens.fast,
                            ),
                            switchInCurve: DtMotionTokens.ease,
                            switchOutCurve: DtMotionTokens.ease,
                            transitionBuilder: (child, animation) {
                              final offset = Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: offset,
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                              i == index ? _items[i].$2 : _items[i].$1,
                              key: ValueKey('${_items[i].$3}-$i-$index'),
                              size: 21,
                              color: i == index
                                  ? (dark
                                        ? const Color(0xFFF5F0E7)
                                        : DtColors.ink)
                                  : (dark
                                        ? const Color(0xFF8D867B)
                                        : DtColors.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].$3,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == index
                                ? (dark
                                      ? const Color(0xFFF5F0E7)
                                      : DtColors.ink)
                                : (dark
                                      ? const Color(0xFF8D867B)
                                      : DtColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
