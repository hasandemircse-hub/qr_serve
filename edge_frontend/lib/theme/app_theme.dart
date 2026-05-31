import 'package:flutter/material.dart';

/// QuickServe Edge admin paneli tema sistemi.
///
/// Renkler `docs/` altındaki menü admin HTML mockup'ından (koyu sidebar + light main +
/// #009ef7 accent) türetildi. Bu tema tüm `edge_frontend` ekranlarına uygulanır;
/// ekrana özgü override yerine `Theme.of(context)` ve [AppPalette] uzantısı kullanın.
class AppTheme {
  AppTheme._();

  // Çekirdek palet (HTML mockup)
  static const Color _bg = Color(0xFFF4F5F7);
  static const Color _sidebarBg = Color(0xFF1E1E2D);
  static const Color _sidebarText = Color(0xFFA1A5B7);
  static const Color _sidebarTextActive = Colors.white;
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF181C32);
  static const Color _textMuted = Color(0xFFA1A5B7);
  static const Color _accent = Color(0xFF009EF7);
  static const Color _border = Color(0xFFE4E6EF);
  static const Color _danger = Color(0xFFF1416C);
  static const Color _success = Color(0xFF50CD89);
  static const Color _inputFill = Color(0xFFF9F9F9);
  static const Color _rowHover = Color(0xFFF9F9F9);

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: _accent,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE1F5FE),
      onPrimaryContainer: Color(0xFF003C5A),
      secondary: _success,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE8FFF3),
      onSecondaryContainer: Color(0xFF1F6B3D),
      error: _danger,
      onError: Colors.white,
      errorContainer: Color(0xFFFFE2E5),
      onErrorContainer: Color(0xFF7A0A2A),
      surface: _surface,
      onSurface: _textMain,
      surfaceContainerLowest: _surface,
      surfaceContainerLow: _bg,
      surfaceContainer: _bg,
      surfaceContainerHigh: _bg,
      surfaceContainerHighest: _bg,
      surfaceTint: _accent,
      outline: _border,
      outlineVariant: _border,
      onSurfaceVariant: Color(0xFF565674),
      inverseSurface: _sidebarBg,
      onInverseSurface: _sidebarText,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      scaffoldBackgroundColor: _bg,
      canvasColor: _surface,
      dividerColor: _border,
      textTheme: base.textTheme.apply(
        bodyColor: _textMain,
        displayColor: _textMain,
        fontFamily: 'Inter',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _textMain,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _textMain,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: _textMain),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: _surface,
        surfaceTintColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: _border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: _sidebarBg,
        surfaceTintColor: _sidebarBg,
        scrimColor: Color(0x66000000),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        indicatorColor: _accent.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: _accent,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(color: _textMuted, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _accent);
          }
          return const IconThemeData(color: _textMuted);
        }),
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: _sidebarBg,
        surfaceTintColor: _sidebarBg,
        indicatorColor: _accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _danger, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF3F4254),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFF7E8299),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _inputFill,
        side: const BorderSide(color: _border),
        labelStyle: const TextStyle(
          color: _textMain,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dividerTheme: const DividerThemeData(
        color: _border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        iconColor: _textMuted,
        textColor: _textMain,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: const TextStyle(
          color: _textMain,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _textMain,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppPalette(
          sidebarBg: _sidebarBg,
          sidebarText: _sidebarText,
          sidebarTextActive: _sidebarTextActive,
          accent: _accent,
          danger: _danger,
          success: _success,
          border: _border,
          textMain: _textMain,
          textMuted: _textMuted,
          rowHover: _rowHover,
          inputFill: _inputFill,
        ),
      ],
    );
  }
}

/// Material 3 `ColorScheme`'in ifade etmediği QuickServe'a özgü renkler.
/// Erişim: `Theme.of(context).extension<AppPalette>()!`
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.sidebarBg,
    required this.sidebarText,
    required this.sidebarTextActive,
    required this.accent,
    required this.danger,
    required this.success,
    required this.border,
    required this.textMain,
    required this.textMuted,
    required this.rowHover,
    required this.inputFill,
  });

  final Color sidebarBg;
  final Color sidebarText;
  final Color sidebarTextActive;
  final Color accent;
  final Color danger;
  final Color success;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final Color rowHover;
  final Color inputFill;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  @override
  AppPalette copyWith({
    Color? sidebarBg,
    Color? sidebarText,
    Color? sidebarTextActive,
    Color? accent,
    Color? danger,
    Color? success,
    Color? border,
    Color? textMain,
    Color? textMuted,
    Color? rowHover,
    Color? inputFill,
  }) {
    return AppPalette(
      sidebarBg: sidebarBg ?? this.sidebarBg,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarTextActive: sidebarTextActive ?? this.sidebarTextActive,
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      border: border ?? this.border,
      textMain: textMain ?? this.textMain,
      textMuted: textMuted ?? this.textMuted,
      rowHover: rowHover ?? this.rowHover,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      sidebarText: Color.lerp(sidebarText, other.sidebarText, t)!,
      sidebarTextActive:
          Color.lerp(sidebarTextActive, other.sidebarTextActive, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      rowHover: Color.lerp(rowHover, other.rowHover, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }
}

/// Responsive breakpoint'leri tek yerden yönetir.
class AppBreakpoints {
  AppBreakpoints._();

  /// Geniş ekran (desktop / büyük tablet): sidebar + main + slide-panel düzeni.
  static const double wide = 900;

  /// Orta ekran (tablet): sidebar daralır, slide-panel full-screen sheet olur.
  static const double medium = 600;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;

  static bool isMedium(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;
}
