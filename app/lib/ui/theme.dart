import 'package:flutter/material.dart';

/// 화면 색(먹·금·주홍·옥) — 무협 분위기, 어두운 바탕에 금빛 강조.
abstract final class Palette {
  static const ink = Color(0xFF17111C);
  static const panel = Color(0xE6221829);
  static const panelLight = Color(0xF02E2236);
  static const gold = Color(0xFFF2C14E);
  static const goldDeep = Color(0xFFB8862B);
  static const red = Color(0xFFD2452F);
  static const redDeep = Color(0xFF8E2418);
  static const jade = Color(0xFF3FA37F);
  static const jadeDeep = Color(0xFF1F6B50);
  static const sky = Color(0xFF3D8FD1);
  static const skyDeep = Color(0xFF1F5A8A);
  static const paper = Color(0xFFF4EAD2);
  static const text = Color(0xFFF7EFE0);
  static const dim = Color(0xB3F7EFE0);
}

/// 글꼴: 제목·숫자는 굵은 Black Han Sans, 나머지는 도현(둘 다 SIL OFL).
const titleFont = 'BlackHanSans';
const bodyFont = 'DoHyeon';

/// 두 글꼴에 없는 기호·한자를 채우는 글꼴(·—…「」·彈指 등).
const fallbackFonts = ['NotoKRFallback'];

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Palette.gold,
        brightness: Brightness.dark,
      ).copyWith(
        primary: Palette.gold,
        onPrimary: const Color(0xFF2A1A08),
        secondary: Palette.red,
        surface: Palette.ink,
        onSurface: Palette.text,
      );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: bodyFont,
    fontFamilyFallback: fallbackFonts,
    scaffoldBackgroundColor: Palette.ink,
  );
  TextStyle? t(TextStyle? s, {bool title = false}) => s?.copyWith(
    fontFamily: title ? titleFont : bodyFont,
    fontFamilyFallback: fallbackFonts,
    color: Palette.text,
    letterSpacing: title ? 0.5 : 0.2,
  );
  final tt = base.textTheme;
  // 글 모양마다 같은 보충 글꼴을 붙인다(도현에 없는 「·」 같은 기호가 네모로 나오지 않게).
  const titleStyle = TextStyle(
    fontFamily: titleFont,
    fontFamilyFallback: fallbackFonts,
  );
  const bodyStyle = TextStyle(
    fontFamily: bodyFont,
    fontFamilyFallback: fallbackFonts,
  );
  final gold40 = Palette.gold.withValues(alpha: 0.4);
  final panelBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
    side: BorderSide(color: Palette.gold.withValues(alpha: 0.45), width: 1.5),
  );
  return base.copyWith(
    textTheme: tt.copyWith(
      displayLarge: t(tt.displayLarge, title: true),
      displayMedium: t(tt.displayMedium, title: true),
      displaySmall: t(tt.displaySmall, title: true),
      headlineLarge: t(tt.headlineLarge, title: true),
      headlineMedium: t(tt.headlineMedium, title: true),
      headlineSmall: t(tt.headlineSmall, title: true),
      titleLarge: t(tt.titleLarge, title: true),
      titleMedium: t(tt.titleMedium),
      titleSmall: t(tt.titleSmall),
      bodyLarge: t(tt.bodyLarge),
      bodyMedium: t(tt.bodyMedium),
      bodySmall: t(tt.bodySmall)?.copyWith(color: Palette.dim),
      labelLarge: t(tt.labelLarge),
      labelMedium: t(tt.labelMedium),
      labelSmall: t(tt.labelSmall),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: titleStyle.copyWith(
        fontSize: 22,
        color: Palette.gold,
        shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
      ),
      iconTheme: const IconThemeData(color: Palette.text),
    ),
    // 옛 기본 카드·목록·선택 단추도 로비와 같은 어두운 판 + 금테로.
    cardTheme: CardThemeData(
      color: Palette.panelLight,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: panelBorder,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Palette.gold,
      textColor: Palette.text,
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      shape: panelBorder,
      titleTextStyle: titleStyle.copyWith(fontSize: 17, color: Palette.text),
      subtitleTextStyle: bodyStyle.copyWith(fontSize: 14, color: Palette.dim),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.panelLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Palette.goldDeep, width: 1.5),
      ),
      titleTextStyle: titleStyle.copyWith(fontSize: 24, color: Palette.gold),
      contentTextStyle: bodyStyle.copyWith(fontSize: 17, color: Palette.text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.gold,
        foregroundColor: const Color(0xFF2A1A08),
        disabledBackgroundColor: const Color(0xFF5A5060),
        disabledForegroundColor: Colors.white54,
        minimumSize: const Size(48, 48),
        textStyle: titleStyle.copyWith(fontSize: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.gold,
        disabledForegroundColor: Colors.white38,
        minimumSize: const Size(48, 48),
        textStyle: titleStyle.copyWith(fontSize: 17),
        side: BorderSide(color: gold40, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.gold,
        minimumSize: const Size(48, 48),
        textStyle: titleStyle.copyWith(fontSize: 17),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        textStyle: WidgetStatePropertyAll(bodyStyle.copyWith(fontSize: 16)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Palette.goldDeep
              : Palette.panel,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Palette.text,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: gold40)),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? Colors.white30 : Palette.gold,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.gold,
      linearTrackColor: Colors.white12,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Palette.panelLight,
      contentTextStyle: bodyStyle.copyWith(fontSize: 16, color: Palette.text),
      behavior: SnackBarBehavior.floating,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.panel,
      selectedColor: Palette.goldDeep,
      disabledColor: Palette.panel,
      checkmarkColor: Colors.white,
      side: BorderSide(color: gold40),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      labelStyle: bodyStyle.copyWith(fontSize: 16, color: Palette.text),
      secondaryLabelStyle: bodyStyle.copyWith(
        fontSize: 16,
        color: Colors.white,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
