import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DtColors {
  const DtColors._();

  static const brand = Color(0xFF5478F6);
  static const brandDeep = Color(0xFF3454D1);
  static const violet = Color(0xFF8E72EA);
  static const mint = Color(0xFF32A99A);
  static const coral = Color(0xFFE07168);
  static const rose = Color(0xFFE590AA);
  static const ink = Color(0xFF171923);
  static const mist = Color(0xFFF3F1ED);
  static const canvas = Color(0xFFF4F2EE);
  static const canvasSoft = Color(0xFFF8F6F2);
  static const surface = Color(0xFFFFFDF9);
  static const surfaceMuted = Color(0xFFF0EDE7);
  static const line = Color(0xFFE7E2DA);
  static const textSecondary = Color(0xFF746F67);
  static const textTertiary = Color(0xFF9B958B);
  static const darkBg = Color(0xFF11100E);
  static const darkSurface = Color(0xFF1A1917);
  static const darkElevated = Color(0xFF24221F);
  static const darkLine = Color(0xFF302D28);
}

class DtRadii {
  const DtRadii._();

  static const card = 22.0;
  static const cardLarge = 28.0;
  static const control = 16.0;
  static const bubble = 20.0;
  static const pill = 999.0;
}

class DtMotionTokens {
  const DtMotionTokens._();

  static const page = Duration(milliseconds: 240);
  static const fast = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 280);
  static const press = Duration(milliseconds: 160);
  static const staggerStep = Duration(milliseconds: 30);
  static const pageOffset = 12.0;
  static const listOffset = 10.0;
  static const ease = Cubic(0.22, 1, 0.36, 1);
}

class DtShadows {
  const DtShadows._();

  static List<BoxShadow> soft(bool dark) => dark
      ? const [
          BoxShadow(
            color: Color(0x3D000000),
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: -2,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x120E0B08),
            blurRadius: 26,
            offset: Offset(0, 9),
            spreadRadius: -10,
          ),
          BoxShadow(
            color: Color(0x090E0B08),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: -2,
          ),
        ];

  static List<BoxShadow> floating(bool dark) => dark
      ? const [
          BoxShadow(
            color: Color(0x52000000),
            blurRadius: 32,
            offset: Offset(0, 14),
            spreadRadius: -10,
          ),
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 10,
            offset: Offset(0, 3),
            spreadRadius: -2,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1A0E0B08),
            blurRadius: 34,
            offset: Offset(0, 15),
            spreadRadius: -12,
          ),
          BoxShadow(
            color: Color(0x0B0E0B08),
            blurRadius: 10,
            offset: Offset(0, 3),
            spreadRadius: -2,
          ),
        ];

  static List<BoxShadow> primary(bool dark) => dark
      ? const [
          BoxShadow(
            color: Color(0x38F7F1E8),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: -8,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x2E17130F),
            blurRadius: 24,
            offset: Offset(0, 10),
            spreadRadius: -8,
          ),
        ];
}

class DtPageTransitionsBuilder extends PageTransitionsBuilder {
  const DtPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
        child: child,
      );
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: DtMotionTokens.ease,
      reverseCurve: DtMotionTokens.ease,
    );
    final position = Tween<Offset>(
      begin: const Offset(0.035, 0),
      end: Offset.zero,
    ).animate(curved);
    final opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    return SlideTransition(
      position: position,
      child: FadeTransition(opacity: opacity, child: child),
    );
  }
}

class DtTheme {
  const DtTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: DtColors.brand,
          brightness: brightness,
          surface: dark ? DtColors.darkSurface : DtColors.surface,
          primary: dark ? const Color(0xFFF5F0E7) : DtColors.ink,
          onPrimary: dark ? const Color(0xFF17140F) : Colors.white,
        ).copyWith(
          secondary: DtColors.violet,
          tertiary: DtColors.mint,
          surfaceContainerHighest: dark
              ? DtColors.darkElevated
              : DtColors.surfaceMuted,
          surfaceContainer: dark ? DtColors.darkSurface : DtColors.surface,
          outline: dark ? DtColors.darkLine : DtColors.line,
          outlineVariant: dark
              ? const Color(0xFF28251F)
              : const Color(0xFFEDE8E0),
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? DtColors.darkBg : DtColors.canvas,
      canvasColor: dark ? DtColors.darkBg : DtColors.canvas,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      fontFamily: kIsWeb ? 'DreamtideWebCJK' : null,
      visualDensity: VisualDensity.standard,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: dark ? const Color(0xFFF0ECE4) : DtColors.ink,
        displayColor: dark ? const Color(0xFFFAF7F1) : DtColors.ink,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: dark ? DtColors.darkSurface : DtColors.surface,
        foregroundColor: dark ? Colors.white : DtColors.ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? DtColors.darkSurface : DtColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DtRadii.card),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? DtColors.darkLine : const Color(0xFFEDE8E0),
        thickness: 0.7,
        space: 0.7,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? DtColors.darkElevated : DtColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DtRadii.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DtRadii.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DtRadii.pill),
          borderSide: BorderSide(
            color: dark ? const Color(0xFFD9D1C4) : DtColors.ink,
            width: 1,
          ),
        ),
        hintStyle: TextStyle(
          color: dark ? const Color(0xFF8C857B) : DtColors.textTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 54)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          foregroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xFF17140F) : Colors.white,
          ),
          backgroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xFFF5F0E7) : DtColors.ink,
          ),
          overlayColor: WidgetStatePropertyAll(
            (dark ? Colors.black : Colors.white).withValues(alpha: 0.08),
          ),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? 0 : 2,
          ),
          shadowColor: WidgetStatePropertyAll(
            (dark ? Colors.black : DtColors.ink).withValues(alpha: 0.22),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          foregroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xFFF0ECE4) : DtColors.ink,
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 50)),
          foregroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xFFF0ECE4) : DtColors.ink,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: dark ? DtColors.darkLine : DtColors.line),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          foregroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xFFF0ECE4) : DtColors.ink,
          ),
          overlayColor: WidgetStatePropertyAll(
            (dark ? Colors.white : DtColors.ink).withValues(alpha: 0.06),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? DtColors.darkSurface : DtColors.surface,
        modalBackgroundColor: dark ? DtColors.darkSurface : DtColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.34),
        modalElevation: 18,
        showDragHandle: true,
        dragHandleColor: dark
            ? const Color(0xFF5C564D)
            : const Color(0xFFD4CEC4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DtRadii.cardLarge),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? DtColors.darkSurface : DtColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DtRadii.cardLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFFF2ECE2) : DtColors.ink,
        contentTextStyle: TextStyle(
          color: dark ? const Color(0xFF17140F) : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return dark ? const Color(0xFF17140F) : Colors.white;
          }
          return dark ? const Color(0xFF8F887E) : const Color(0xFFF9F7F3);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return dark ? const Color(0xFFF5F0E7) : DtColors.ink;
          }
          return dark ? DtColors.darkElevated : const Color(0xFFD9D3CA);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: dark ? const Color(0xFFF5F0E7) : DtColors.ink,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: DtPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: DtPageTransitionsBuilder(),
          TargetPlatform.linux: DtPageTransitionsBuilder(),
        },
      ),
    );
  }
}
