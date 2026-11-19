import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/app_controller.dart';
import 'domain/models.dart';
import 'router/app_router.dart';
import 'ui/screens/age_gate_page.dart';
import 'ui/theme/dt_theme.dart';

class DreamtideApp extends ConsumerWidget {
  const DreamtideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final themeMode = switch (state.data.settings.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
    if (state.loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DtTheme.light(),
        darkTheme: DtTheme.dark(),
        home: const _LoadingPage(),
      );
    }
    if (!state.data.settings.ageConfirmed) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '触梦 Dreamtide',
        theme: DtTheme.light(),
        darkTheme: DtTheme.dark(),
        themeMode: themeMode,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AgeGatePage(),
      );
    }
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: '触梦 Dreamtide',
      routerConfig: router,
      theme: DtTheme.light(),
      darkTheme: DtTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final content = MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
        if (!kIsWeb || media.size.width < 720) return content;

        final dark = Theme.of(context).brightness == Brightness.dark;
        final width = media.size.width.clamp(440, 560).toDouble();
        final verticalInset = media.size.height >= 760 ? 18.0 : 0.0;
        final appHeight = media.size.height - verticalInset * 2;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF0C0B09), Color(0xFF171510)]
                  : const [Color(0xFFE9E4DB), Color(0xFFF8F5EF)],
            ),
          ),
          child: Center(
            child: SizedBox(
              width: width,
              height: appHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    verticalInset == 0 ? 0 : 28,
                  ),
                  boxShadow: DtShadows.floating(dark),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    verticalInset == 0 ? 0 : 28,
                  ),
                  child: MediaQuery(
                    data: media.copyWith(
                      size: Size(width, appHeight),
                      textScaler: media.textScaler.clamp(
                        minScaleFactor: 0.9,
                        maxScaleFactor: 1.15,
                      ),
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [DtColors.darkElevated, DtColors.darkBg]
                : const [DtColors.canvasSoft, DtColors.canvas],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(height: 18),
              Text('正在进入梦境', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
