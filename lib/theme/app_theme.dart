import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Design tokens semantik untuk Modern Clean Light & OLED Dark
@immutable
class PosColors extends ThemeExtension<PosColors> {
  final Color bgCanvas;
  final Color surfacePrimary;
  final Color surfaceElevated;
  final Color surfaceHighlight;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color brandPrimary;
  final Color brandOnPrimary;
  final Color statusSuccess;
  final Color statusWarning;
  final Color statusDanger;
  final Color statusInfo;

  const PosColors({
    required this.bgCanvas,
    required this.surfacePrimary,
    required this.surfaceElevated,
    required this.surfaceHighlight,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brandPrimary,
    required this.brandOnPrimary,
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusDanger,
    required this.statusInfo,
  });

  static const PosColors light = PosColors(
    bgCanvas: Color(0xFFF8FAFC),
    surfacePrimary: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9),
    surfaceHighlight: Color(0xFFEFF6FF),
    borderSubtle: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    brandPrimary: Color(0xFF2563EB),
    brandOnPrimary: Color(0xFFFFFFFF),
    statusSuccess: Color(0xFF059669),
    statusWarning: Color(0xFFD97706),
    statusDanger: Color(0xFFDC2626),
    statusInfo: Color(0xFF0284C7),
  );

  static const PosColors dark = PosColors(
    bgCanvas: Color(0xFF000000),
    surfacePrimary: Color(0xFF0D1117),
    surfaceElevated: Color(0xFF161B22),
    surfaceHighlight: Color(0xFF172554),
    borderSubtle: Color(0xFF1F2937),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    brandPrimary: Color(0xFF3B82F6),
    brandOnPrimary: Color(0xFFFFFFFF),
    statusSuccess: Color(0xFF10B981),
    statusWarning: Color(0xFFF59E0B),
    statusDanger: Color(0xFFEF4444),
    statusInfo: Color(0xFF38BDF8),
  );

  @override
  PosColors copyWith({
    Color? bgCanvas,
    Color? surfacePrimary,
    Color? surfaceElevated,
    Color? surfaceHighlight,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? brandPrimary,
    Color? brandOnPrimary,
    Color? statusSuccess,
    Color? statusWarning,
    Color? statusDanger,
    Color? statusInfo,
  }) {
    return PosColors(
      bgCanvas: bgCanvas ?? this.bgCanvas,
      surfacePrimary: surfacePrimary ?? this.surfacePrimary,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandOnPrimary: brandOnPrimary ?? this.brandOnPrimary,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusWarning: statusWarning ?? this.statusWarning,
      statusDanger: statusDanger ?? this.statusDanger,
      statusInfo: statusInfo ?? this.statusInfo,
    );
  }

  @override
  PosColors lerp(ThemeExtension<PosColors>? other, double t) {
    if (other is! PosColors) return this;
    return PosColors(
      bgCanvas: Color.lerp(bgCanvas, other.bgCanvas, t)!,
      surfacePrimary: Color.lerp(surfacePrimary, other.surfacePrimary, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceHighlight: Color.lerp(surfaceHighlight, other.surfaceHighlight, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandOnPrimary: Color.lerp(brandOnPrimary, other.brandOnPrimary, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusDanger: Color.lerp(statusDanger, other.statusDanger, t)!,
      statusInfo: Color.lerp(statusInfo, other.statusInfo, t)!,
    );
  }
}

extension PosThemeContext on BuildContext {
  PosColors get posColors =>
      Theme.of(this).extension<PosColors>() ?? PosColors.light;

  bool get isTablet => MediaQuery.sizeOf(this).width >= 720;
}

class AppTheme {
  static const double tabletBreakpoint = 720.0;

  static TextStyle tabular(TextStyle? base, {double? fontSize, FontWeight? fontWeight, Color? color}) {
    return (base ?? const TextStyle()).copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData get lightTheme => _buildTheme(Brightness.light, PosColors.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark, PosColors.dark);

  static ThemeData _buildTheme(Brightness brightness, PosColors colors) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.brandPrimary,
      onPrimary: colors.brandOnPrimary,
      secondary: colors.statusInfo,
      onSecondary: Colors.white,
      error: colors.statusDanger,
      onError: Colors.white,
      surface: colors.surfacePrimary,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceElevated,
      outline: colors.borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.bgCanvas,
      extensions: [colors],
      dividerColor: colors.borderSubtle,
      dividerTheme: DividerThemeData(
        color: colors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfacePrimary,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shape: Border(bottom: BorderSide(color: colors.borderSubtle, width: 1)),
      ),
      cardTheme: CardThemeData(
        color: colors.surfacePrimary,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.brandPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.statusDanger),
        ),
        hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brandPrimary,
          foregroundColor: colors.brandOnPrimary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.borderSubtle),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.brandPrimary,
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceElevated,
        selectedColor: colors.surfaceHighlight,
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        side: BorderSide(color: colors.borderSubtle),
        shape: const StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfacePrimary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.borderSubtle),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfacePrimary,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfacePrimary,
        indicatorColor: colors.surfaceHighlight,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.brandPrimary : colors.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfacePrimary,
        indicatorColor: colors.surfaceHighlight,
        selectedIconTheme: IconThemeData(color: colors.brandPrimary),
        unselectedIconTheme: IconThemeData(color: colors.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: colors.brandPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? colors.surfaceElevated : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class PosFormatters {
  static final NumberFormat _idrFormat = NumberFormat.decimalPattern('id_ID');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  static String currency(num amount, {String symbol = 'Rp'}) {
    final isNeg = amount < 0;
    final absVal = amount.abs().round();
    final formatted = _idrFormat.format(absVal);
    return '${isNeg ? '-' : ''}$symbol $formatted';
  }

  static String number(num value) {
    if (value == value.roundToDouble()) {
      return _idrFormat.format(value.round());
    }
    return value.toStringAsFixed(2);
  }

  static String dateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    return dt == null ? iso : _dateTimeFormat.format(dt);
  }

  static String date(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    return dt == null ? iso : _dateFormat.format(dt);
  }

  static String time(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    return dt == null ? iso : _timeFormat.format(dt);
  }
}
