import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forui/forui.dart';

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
        child: navigationShell,
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

class _QqBottomBar extends StatelessWidget {
  const _QqBottomBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;
  static const _items = [
    (FIcons.messageCircle, '消息'),
    (FIcons.users, '联系人'),
    (FIcons.circleDot, '动态'),
  ];
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('root-bottom-bar'),
      decoration: BoxDecoration(
        color: dark ? DtColors.darkSurface : DtColors.surface,
        border: Border(
          top: BorderSide(
            color: dark ? DtColors.darkLine : DtColors.line,
            width: .5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: DtPressable(
                    onTap: () => onTap(i),
                    semanticLabel: _items[i].$2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items[i].$1,
                          size: 24,
                          color: i == index
                              ? DtColors.violet
                              : DtColors.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].$2,
                          style: TextStyle(
                            fontSize: 11,
                            color: i == index
                                ? DtColors.violet
                                : DtColors.textSecondary,
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
