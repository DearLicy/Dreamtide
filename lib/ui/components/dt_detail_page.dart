import 'package:flutter/material.dart';

import '../theme/dt_theme.dart';

class DtDetailPage extends StatelessWidget {
  const DtDetailPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottom;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? DtColors.darkBg : DtColors.canvas,
      appBar: AppBar(
        backgroundColor: dark ? DtColors.darkSurface : DtColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: dark
                      ? const Color(0xFF8B94A8)
                      : const Color(0xFF8C95A6),
                ),
              ),
            ],
          ],
        ),
        actions: [...actions, const SizedBox(width: 6)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.7),
          child: Divider(
            color: dark ? DtColors.darkLine : const Color(0xFFE9E3DA),
          ),
        ),
      ),
      body: Padding(padding: padding, child: child),
      bottomNavigationBar: bottom,
    );
  }
}
