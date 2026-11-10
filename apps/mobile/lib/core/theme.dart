import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Zaad design tokens. Brand palette as specified by Zaad:
/// primary #2224C6 · white · background #F5F6FC · text #191B32 · secondary text #777B99 · light blue #E9EAFE.
/// Blue variations below are only used for gradients/depth.
class ZaadColors {
  static const primary = Color(0xFF2224C6);
  static const primaryBright = Color(0xFF3A3CDB); // gradient highlight
  static const primaryDark = Color(0xFF1719A3); // gradient shade
  static const primaryDeep = Color(0xFF10128A); // deepest gradient stop
  static const primarySoft = Color(0xFFE9EAFE);
  // Welcome/onboarding palette (Zaad brief): deep #1517A8, bright #3038F5, light #E9ECFF, on-blue text #D9DCFF.
  static const welcomeDeep = Color(0xFF1517A8);
  static const welcomeBright = Color(0xFF3038F5);
  static const welcomeLight = Color(0xFFE9ECFF);
  static const onBlueMuted = Color(0xFFD9DCFF);
  static const background = Color(0xFFF5F6FC);
  static const surface = Colors.white;
  static const text = Color(0xFF191B32);
  static const textMuted = Color(0xFF777B99);
  static const border = Color(0xFFE6E8F4);
  static const success = Color(0xFF12805C);
  static const successSoft = Color(0xFFE4F5EE);
  static const danger = Color(0xFFC2352B);
  static const dangerSoft = Color(0xFFFCEBE9);
  static const warning = Color(0xFF9A6200);
  static const warningSoft = Color(0xFFFFF4DD);
}

/// 4-pt spacing scale.
class ZaadSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
  static const page = 20.0; // horizontal page gutter
  static const radius = 20.0; // cards
  static const radiusSm = 14.0; // inner tiles, buttons
  static const radiusXl = 28.0; // hero card, header
}

/// Motion tokens — one vocabulary for every animation in the app.
/// Short and decelerating: things settle into place, nothing bounces or loops.
class ZaadMotion {
  static const fast = Duration(milliseconds: 150); // press feedback, small toggles
  static const base = Duration(milliseconds: 280); // indicators, chips, page transitions
  static const slow = Duration(milliseconds: 420); // entrance of cards and sections
  static const count = Duration(milliseconds: 1100); // number counting (points balance)
  static const stagger = Duration(milliseconds: 60); // delay step between list items
  static const curve = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutQuart;
}

/// Shadows are tinted with the brand blue so depth reads as "Zaad", not grey.
class ZaadShadows {
  static const card = [BoxShadow(color: Color(0x0F2224C6), blurRadius: 24, offset: Offset(0, 8))];
  static const raised = [BoxShadow(color: Color(0x332224C6), blurRadius: 32, offset: Offset(0, 14))];
  static const nav = [BoxShadow(color: Color(0x1A191B32), blurRadius: 28, offset: Offset(0, 8))];
  static const soft = [BoxShadow(color: Color(0x0A2224C6), blurRadius: 16, offset: Offset(0, 4))];
  static const glow = [BoxShadow(color: Color(0x552224C6), blurRadius: 40, offset: Offset(0, 18), spreadRadius: -6)];
}

class ZaadGradients {
  static const hero = LinearGradient(
    colors: [ZaadColors.primaryBright, ZaadColors.primary, ZaadColors.primaryDeep],
    stops: [0, 0.45, 1],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );
  /// Very light blue wash behind light headers (home, auth).
  static const wash = LinearGradient(
    colors: [Color(0xFFE6E8FF), Color(0xFFF1F2FD), ZaadColors.background],
    stops: [0, 0.55, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const header = LinearGradient(
    colors: [ZaadColors.primary, ZaadColors.primaryDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

const _font = 'IBMPlexSansArabic';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ZaadColors.primary,
    primary: ZaadColors.primary,
    surface: ZaadColors.surface,
    error: ZaadColors.danger,
    onSurface: ZaadColors.text,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: _font, scaffoldBackgroundColor: ZaadColors.background);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaadSpace.radiusSm));
  const buttonText = TextStyle(fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w600);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: ZaadColors.text, displayColor: ZaadColors.text),
    // Soft fade + short rise on Android/web; native slide (with swipe-back) on iOS.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZaadPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: ZaadPageTransitionsBuilder(),
      TargetPlatform.windows: ZaadPageTransitionsBuilder(),
    }),
    // Round white back button (reference design); BackButtonIcon mirrors itself in RTL.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: ZaadColors.surface, shape: BoxShape.circle, boxShadow: ZaadShadows.soft),
        child: const Icon(Icons.arrow_back_rounded, size: 22, color: ZaadColors.text),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ZaadColors.background,
      foregroundColor: ZaadColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: _font, fontSize: 17, fontWeight: FontWeight.w700, color: ZaadColors.text),
    ),
    cardTheme: CardThemeData(
      color: ZaadColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaadSpace.radius), side: const BorderSide(color: ZaadColors.border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: buttonShape, textStyle: buttonText, elevation: 0),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: buttonShape,
        side: const BorderSide(color: ZaadColors.border),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZaadColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaadSpace.radiusSm), borderSide: const BorderSide(color: ZaadColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaadSpace.radiusSm), borderSide: const BorderSide(color: ZaadColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZaadSpace.radiusSm), borderSide: const BorderSide(color: ZaadColors.primary, width: 1.5)),
    ),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaadSpace.radius))),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZaadColors.text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZaadSpace.radiusSm)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(selectedBackgroundColor: ZaadColors.primarySoft, selectedForegroundColor: ZaadColors.primary),
    ),
    dividerTheme: const DividerThemeData(color: ZaadColors.border, space: 1, thickness: 1),
  );
}

/// Page transition: the new page fades in while rising 24px; the old page dims slightly.
/// Respects the OS "reduce motion" setting.
class ZaadPageTransitionsBuilder extends PageTransitionsBuilder {
  const ZaadPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final enter = CurvedAnimation(parent: animation, curve: ZaadMotion.curve, reverseCurve: Curves.easeInCubic);
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: ZaadMotion.curve);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.92).animate(exit),
      child: FadeTransition(
        opacity: enter,
        child: AnimatedBuilder(
          animation: enter,
          builder: (_, c) => Transform.translate(offset: Offset(0, 24 * (1 - enter.value)), child: c),
          child: ColoredBox(color: ZaadColors.background, child: child),
        ),
      ),
    );
  }
}
