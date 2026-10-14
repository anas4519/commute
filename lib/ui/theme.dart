import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Spacing scale: 4 / 8 / 12 / 16 / 20 / 24 / 32.
abstract final class Space {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
  static const screen = EdgeInsets.symmetric(horizontal: xl);
  static const radius = 20.0, radiusSm = 14.0;
}

/// Small palette per brightness. One calm accent.
class Palette {
  final Color bg, surface, surfaceHi, border, text, textMuted, accent, onAccent, danger;
  const Palette({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.danger,
  });

  static const dark = Palette(
    bg: Color(0xFF0E0F12),
    surface: Color(0xFF16181D),
    surfaceHi: Color(0xFF1E2128),
    border: Color(0xFF262A32),
    text: Color(0xFFECEDEF),
    textMuted: Color(0xFF8A8F98),
    accent: Color(0xFF7C9CFF),
    onAccent: Color(0xFF0E0F12),
    danger: Color(0xFFFF7A7A),
  );

  static const light = Palette(
    bg: Color(0xFFF6F6F4),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFF0F0EE),
    border: Color(0xFFE4E4E0),
    text: Color(0xFF15161A),
    textMuted: Color(0xFF6B6F76),
    accent: Color(0xFF3D5AFE),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFD93A3A),
  );

  static Palette of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme(
    brightness: b,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.danger,
    onError: p.onAccent,
    surface: p.bg,
    onSurface: p.text,
    onSurfaceVariant: p.textMuted,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceHi,
    surfaceContainerHighest: p.surfaceHi,
    outline: p.border,
    outlineVariant: p.border,
    secondaryContainer: p.surfaceHi,
    onSecondaryContainer: p.text,
  );

  final baseText = ThemeData(brightness: b, fontFamily: 'Inter').textTheme;
  final text = baseText
      .copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          height: 1.1,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
        bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
        bodySmall: baseText.bodySmall?.copyWith(fontSize: 13, height: 1.35),
        labelLarge: baseText.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        labelMedium: baseText.labelMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      )
      .apply(bodyColor: p.text, displayColor: p.text);

  final overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness: b == Brightness.dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: b,
    systemNavigationBarIconBrightness: b == Brightness.dark ? Brightness.light : Brightness.dark,
  );

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Space.radiusSm),
    borderSide: BorderSide(color: p.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    fontFamily: 'Inter',
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: p.border,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: overlay,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: p.text),
    ),
    iconTheme: IconThemeData(color: p.textMuted, size: 22),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      hintStyle: text.bodyLarge?.copyWith(color: p.textMuted),
      prefixIconColor: p.textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.lg),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: p.accent, width: 1.2)),
      errorBorder: border.copyWith(borderSide: BorderSide(color: p.danger)),
      focusedErrorBorder: border.copyWith(borderSide: BorderSide(color: p.danger, width: 1.2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.surfaceHi,
        disabledForegroundColor: p.textMuted,
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Space.radiusSm)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: p.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Space.radiusSm)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.surfaceHi : p.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.text : p.textMuted,
        ),
        textStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      selectedIcon: const SizedBox.shrink(),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(p.border),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onAccent : p.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHi,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: p.border,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surfaceHi,
      contentTextStyle: text.bodyMedium,
      actionTextColor: p.accent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Space.radiusSm),
        side: BorderSide(color: p.border),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent, linearTrackColor: Colors.transparent),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      minVerticalPadding: Space.md,
      iconColor: p.textMuted,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall?.copyWith(color: p.textMuted),
    ),
  );
}
