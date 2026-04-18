import 'package:flutter/material.dart';

/// Warna semantik app — ikut tema terang/gelap melalui [ThemeExtension].
@immutable
class StaffAppColors extends ThemeExtension<StaffAppColors> {
  const StaffAppColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.primaryBlue,
    required this.accentBlue,
    required this.lightBlue,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderBlue,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color primaryBlue;
  final Color accentBlue;
  final Color lightBlue;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderBlue;

  static const StaffAppColors dark = StaffAppColors(
    background: Color(0xFF000000),
    surface: Color(0xFF0D1B2A),
    card: Color(0xFF1B263B),
    primaryBlue: Color(0xFF1565C0),
    accentBlue: Color(0xFF42A5F5),
    lightBlue: Color(0xFF64B5F6),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0BEC5),
    borderBlue: Color(0xFF1976D2),
  );

  static const StaffAppColors light = StaffAppColors(
    background: Color(0xFFF0F4F8),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFE3E8EF),
    primaryBlue: Color(0xFF1565C0),
    accentBlue: Color(0xFF1976D2),
    lightBlue: Color(0xFF42A5F5),
    textPrimary: Color(0xFF0D1B2A),
    textSecondary: Color(0xFF546E7A),
    borderBlue: Color(0xFF1976D2),
  );

  @override
  StaffAppColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? primaryBlue,
    Color? accentBlue,
    Color? lightBlue,
    Color? textPrimary,
    Color? textSecondary,
    Color? borderBlue,
  }) {
    return StaffAppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      primaryBlue: primaryBlue ?? this.primaryBlue,
      accentBlue: accentBlue ?? this.accentBlue,
      lightBlue: lightBlue ?? this.lightBlue,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      borderBlue: borderBlue ?? this.borderBlue,
    );
  }

  @override
  StaffAppColors lerp(ThemeExtension<StaffAppColors>? other, double t) {
    if (other is! StaffAppColors) return this;
    return StaffAppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      primaryBlue: Color.lerp(primaryBlue, other.primaryBlue, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      lightBlue: Color.lerp(lightBlue, other.lightBlue, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      borderBlue: Color.lerp(borderBlue, other.borderBlue, t)!,
    );
  }
}

extension StaffThemeContext on BuildContext {
  StaffAppColors get appColors => Theme.of(this).extension<StaffAppColors>() ?? StaffAppColors.dark;
}

/// ThemeData untuk [MaterialApp]; warna kustom akses melalui [StaffThemeContext.appColors].
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: StaffAppColors.dark.background,
      extensions: const [StaffAppColors.dark],
      colorScheme: ColorScheme.dark(
        primary: StaffAppColors.dark.primaryBlue,
        secondary: StaffAppColors.dark.accentBlue,
        surface: StaffAppColors.dark.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: StaffAppColors.dark.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: StaffAppColors.dark.surface,
        foregroundColor: StaffAppColors.dark.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: StaffAppColors.dark.card,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StaffAppColors.dark.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: StaffAppColors.dark.borderBlue, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: StaffAppColors.dark.accentBlue, width: 2),
        ),
        labelStyle: TextStyle(color: StaffAppColors.dark.textSecondary),
        hintStyle: TextStyle(color: StaffAppColors.dark.textSecondary.withValues(alpha: 0.7)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StaffAppColors.dark.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StaffAppColors.dark.accentBlue,
          side: BorderSide(color: StaffAppColors.dark.accentBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: StaffAppColors.light.background,
      extensions: const [StaffAppColors.light],
      colorScheme: ColorScheme.light(
        primary: StaffAppColors.light.primaryBlue,
        secondary: StaffAppColors.light.accentBlue,
        surface: StaffAppColors.light.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: StaffAppColors.light.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: StaffAppColors.light.surface,
        foregroundColor: StaffAppColors.light.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: StaffAppColors.light.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StaffAppColors.light.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: StaffAppColors.light.accentBlue, width: 2),
        ),
        labelStyle: TextStyle(color: StaffAppColors.light.textSecondary),
        hintStyle: TextStyle(color: StaffAppColors.light.textSecondary.withValues(alpha: 0.75)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StaffAppColors.light.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StaffAppColors.light.primaryBlue,
          side: BorderSide(color: StaffAppColors.light.primaryBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
