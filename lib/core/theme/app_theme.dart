// lib/core/theme/app_theme.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════
//  ZYNKUP — Premium Olive-Gold-Orange Design System
//  Palette: Sand · Gold · Orange · Warm Brown · Deep Olive · Off White
// ═══════════════════════════════════════════════════════════════════

class ZynkColors {
  static const sand = Color(0xFFD6D09E);
  static const gold = Color(0xFFC0B348);
  static const orange = Color(0xFFFA7F1C);
  static const warmBrown = Color(0xFF887F5A);
  static const deepOlive = Color(0xFF3D3C21);
  static const offWhite = Color(0xFFF6F0EB);

  // ── Brand ────────────────────────────────────────────────────────
  static const primary = orange;
  static const primaryDark = Color(0xFFC95D13);
  static const primaryLight = Color(0xFFFFA45E);
  static const accent = gold;
  static const accentLight = sand;

  // ── Terracotta ────────────────────────────────────────────────────
  static const terra1 = Color(0xFFB5451B);
  static const terra2 = Color(0xFFD4622E);
  static const terra3 = Color(0xFFE8875A);

  // ── Dark surfaces ─────────────────────────────────────────────────
  static const darkBg = Color(0xFF050505);
  static const darkSurface = Color(0xFF0F0F0F);
  static const darkSurface2 = Color(0xFF161616);
  static const darkBorder = Color(0xFF202020);
  static const darkText = offWhite;
  static const darkMuted = Color(0xFFB3A68D);

  // ── Light surfaces ────────────────────────────────────────────────
  static const lightBg = Color(0xFFFAF6F1);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurf2 = Color(0xFFF5EDE4);
  static const lightBorder = Color(0xFFE8D8CC);
  static const lightText = Color(0xFF2A1F18);
  static const lightMuted = Color(0xFF8A7060);

  // ── Semantic ──────────────────────────────────────────────────────
  static const success = Color(0xFF4CAF7D);
  static const error = Color(0xFFE53935);
  static const warning = Color(0xFFFFB300);

  // ── Category ─────────────────────────────────────────────────────
  static const catTech = Color(0xFF5C9EE8);
  static const catCultural = gold;
  static const catSports = Color(0xFF4CAF7D);
  static const catWorkshop = orange;
  static const catSeminar = Color(0xFF9C6FBF);

  static Color forCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'tech':
        return catTech;
      case 'cultural':
        return catCultural;
      case 'sports':
        return catSports;
      case 'workshop':
        return catWorkshop;
      case 'seminar':
        return catSeminar;
      default:
        return primary;
    }
  }

  // ── Profile Themes ──────────────────────────────────────────────
  static const neonCyber = Color(0xFF00F2FF);
  static const emeraldForest = Color(0xFF00FF88);
  static const spacePurple = Color(0xFFBF00FF);
  static const hackerGreen = Color(0xFF39FF14);
}

class ZynkGradients {
  static const brand = LinearGradient(
    colors: [ZynkColors.primaryDark, ZynkColors.orange, ZynkColors.gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warmDark = LinearGradient(
    colors: [Color(0xFF050505), Color(0xFF0C0C0C), Color(0xFF101010)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Subtle card surface gradient for premium feel
  static const cardSurface = LinearGradient(
    colors: [Color(0xFF0D0D0D), Color(0xFF080808)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gold shimmer gradient for premium accents
  static const goldShimmer = LinearGradient(
    colors: [ZynkColors.gold, ZynkColors.sand, ZynkColors.gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Button gradient
  static const buttonPrimary = LinearGradient(
    colors: [Color(0xFFFA7F1C), Color(0xFFD4622E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const gold = LinearGradient(
    colors: [ZynkColors.accent, ZynkColors.accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient forCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'tech':
        return const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF5C9EE8)],
        );
      case 'cultural':
        return const LinearGradient(
          colors: [ZynkColors.deepOlive, ZynkColors.gold],
        );
      case 'sports':
        return const LinearGradient(
          colors: [Color(0xFF1A3D2B), Color(0xFF4CAF7D)],
        );
      case 'workshop':
        return const LinearGradient(
          colors: [ZynkColors.primaryDark, ZynkColors.orange],
        );
      case 'seminar':
        return const LinearGradient(
          colors: [Color(0xFF3D1A5F), Color(0xFF9C6FBF)],
        );
      default:
        return brand;
    }
  }

  static LinearGradient forTheme(String theme) {
    switch (theme.toLowerCase()) {
      case 'neon_cyber':
        return const LinearGradient(colors: [Color(0xFF0061FF), Color(0xFF60EFFF)]);
      case 'emerald_forest':
        return const LinearGradient(colors: [Color(0xFF134E5E), Color(0xFF71B280)]);
      case 'space_purple':
        return const LinearGradient(colors: [Color(0xFF654ea3), Color(0xFFeaafc8)]);
      case 'hacker_green':
        return const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF2C5364), Color(0xFF00F260)]);
      case 'midnight_orange':
      default:
        return brand;
    }
  }
}

// ── Spacing tokens (8px grid) ───────────────────────────────────────
class ZynkSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

// ── Border radius tokens ────────────────────────────────────────────
class ZynkRadius {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 22.0;
  static const pill = 999.0;
}

// ── Shadows ─────────────────────────────────────────────────────────
class ZynkShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.22),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: ZynkColors.deepOlive.withValues(alpha: 0.08),
      blurRadius: 48,
      offset: const Offset(0, 16),
    ),
  ];

  static List<BoxShadow> button = [
    BoxShadow(
      color: ZynkColors.primary.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> nav = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.32),
      blurRadius: 28,
      offset: const Offset(0, -4),
    ),
  ];

  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.22),
      blurRadius: 18,
    ),
  ];

  static List<BoxShadow> categoryGlow(String category) {
    final color = ZynkColors.forCategory(category);
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.08),
        blurRadius: 36,
        spreadRadius: 2,
      ),
    ];
  }
}

class AppTheme {
  static InputDecorationTheme _input(bool dark) => InputDecorationTheme(
    filled: true,
    fillColor: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.md),
      borderSide: BorderSide(
        color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.md),
      borderSide: BorderSide(
        color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.lg),
      borderSide: const BorderSide(color: ZynkColors.gold, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.md),
      borderSide: const BorderSide(color: ZynkColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.md),
      borderSide: const BorderSide(color: ZynkColors.error, width: 2),
    ),
    labelStyle: TextStyle(
      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      color: (dark ? ZynkColors.darkMuted : ZynkColors.lightMuted).withValues(alpha: 0.6),
    ),
    prefixIconColor: ZynkColors.gold,
    suffixIconColor: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
  );

  static CardThemeData _card(bool dark) => CardThemeData(
    color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
    elevation: 0,
    shadowColor: ZynkColors.deepOlive.withValues(alpha: 0.12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.xl),
      side: BorderSide(
        color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
      ),
    ),
  );

  static AppBarTheme _appBar(bool dark) => AppBarTheme(
    backgroundColor: dark ? ZynkColors.darkBg : ZynkColors.lightBg,
    foregroundColor: dark ? ZynkColors.darkText : ZynkColors.lightText,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: dark ? ZynkColors.darkText : ZynkColors.lightText,
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    iconTheme: const IconThemeData(color: ZynkColors.gold, size: 22),
    actionsIconTheme: const IconThemeData(color: ZynkColors.gold, size: 22),
  );

  static ElevatedButtonThemeData get _btn => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: ZynkColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.lg)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: 0.3,
      ),
    ),
  );

  static OutlinedButtonThemeData get _outlineBtn => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ZynkColors.gold,
      side: const BorderSide(color: ZynkColors.gold, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.lg)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  );

  static TextButtonThemeData get _textBtn => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: ZynkColors.orange,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.md)),
    ),
  );

  static TabBarThemeData _tabBar(bool dark) => TabBarThemeData(
    indicatorColor: ZynkColors.gold,
    indicatorSize: TabBarIndicatorSize.label,
    labelColor: dark ? ZynkColors.offWhite : ZynkColors.lightText,
    unselectedLabelColor: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    dividerColor: Colors.transparent,
  );

  static DialogThemeData _dialog(bool dark) => DialogThemeData(
    backgroundColor: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.xl),
      side: BorderSide(
        color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
      ),
    ),
    titleTextStyle: TextStyle(
      color: dark ? ZynkColors.darkText : ZynkColors.lightText,
      fontSize: 18,
      fontWeight: FontWeight.w800,
    ),
    contentTextStyle: TextStyle(
      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
      fontSize: 14,
      height: 1.5,
    ),
  );

  static ChipThemeData _chip(bool dark) => ChipThemeData(
    backgroundColor: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
    selectedColor: ZynkColors.deepOlive,
    labelStyle: TextStyle(
      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
    secondaryLabelStyle: const TextStyle(
      color: ZynkColors.gold,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.pill),
      side: BorderSide(
        color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
      ),
    ),
    showCheckmark: false,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  static ThemeData get dark {
    final baseTextTheme = ThemeData.dark().textTheme;
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      textTheme: GoogleFonts.outfitTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.sora(textStyle: baseTextTheme.displayLarge),
        displayMedium: GoogleFonts.sora(textStyle: baseTextTheme.displayMedium),
        displaySmall: GoogleFonts.sora(textStyle: baseTextTheme.displaySmall),
        headlineLarge: GoogleFonts.sora(textStyle: baseTextTheme.headlineLarge, fontWeight: FontWeight.w900),
        headlineMedium: GoogleFonts.sora(textStyle: baseTextTheme.headlineMedium, fontWeight: FontWeight.w800),
        headlineSmall: GoogleFonts.sora(textStyle: baseTextTheme.headlineSmall, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.sora(textStyle: baseTextTheme.titleLarge, fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.sora(textStyle: baseTextTheme.titleMedium, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.sora(textStyle: baseTextTheme.titleSmall, fontWeight: FontWeight.w600),
      ),
      colorScheme: const ColorScheme.dark(
        primary: ZynkColors.primary,
        secondary: ZynkColors.accent,
        surface: ZynkColors.darkSurface,
        error: ZynkColors.error,
        onPrimary: Colors.white,
        onSurface: ZynkColors.darkText,
        onSecondary: Colors.white,
      ),
      scaffoldBackgroundColor: ZynkColors.darkBg,
      appBarTheme: _appBar(true),
      cardTheme: _card(true),
      inputDecorationTheme: _input(true),
      elevatedButtonTheme: _btn,
      outlinedButtonTheme: _outlineBtn,
      textButtonTheme: _textBtn,
      tabBarTheme: _tabBar(true),
      dialogTheme: _dialog(true),
      chipTheme: _chip(true),
      dividerColor: ZynkColors.darkBorder,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZynkColors.darkSurface2,
        contentTextStyle: const TextStyle(color: ZynkColors.darkText, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZynkRadius.md),
          side: BorderSide(color: ZynkColors.gold.withValues(alpha: 0.2)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return ZynkColors.deepOlive;
            return ZynkColors.darkSurface2;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return ZynkColors.gold;
            return ZynkColors.darkMuted;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: ZynkColors.darkBorder),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.lg)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ZynkColors.darkSurface2,
          borderRadius: BorderRadius.circular(ZynkRadius.sm),
          border: Border.all(color: ZynkColors.darkBorder),
        ),
        textStyle: const TextStyle(color: ZynkColors.darkText, fontSize: 12),
      ),
    );
  }

  static ThemeData get light {
    final baseTextTheme = ThemeData.light().textTheme;
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      textTheme: GoogleFonts.outfitTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.sora(textStyle: baseTextTheme.displayLarge),
        displayMedium: GoogleFonts.sora(textStyle: baseTextTheme.displayMedium),
        displaySmall: GoogleFonts.sora(textStyle: baseTextTheme.displaySmall),
        headlineLarge: GoogleFonts.sora(textStyle: baseTextTheme.headlineLarge, fontWeight: FontWeight.w900),
        headlineMedium: GoogleFonts.sora(textStyle: baseTextTheme.headlineMedium, fontWeight: FontWeight.w800),
        headlineSmall: GoogleFonts.sora(textStyle: baseTextTheme.headlineSmall, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.sora(textStyle: baseTextTheme.titleLarge, fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.sora(textStyle: baseTextTheme.titleMedium, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.sora(textStyle: baseTextTheme.titleSmall, fontWeight: FontWeight.w600),
      ),
      colorScheme: const ColorScheme.light(
        primary: ZynkColors.primary,
        secondary: ZynkColors.accent,
        surface: ZynkColors.lightSurface,
        error: ZynkColors.error,
        onPrimary: Colors.white,
        onSurface: ZynkColors.lightText,
        onSecondary: Colors.white,
      ),
      scaffoldBackgroundColor: ZynkColors.lightBg,
      appBarTheme: _appBar(false),
      cardTheme: _card(false),
      inputDecorationTheme: _input(false),
      elevatedButtonTheme: _btn,
      outlinedButtonTheme: _outlineBtn,
      textButtonTheme: _textBtn,
      tabBarTheme: _tabBar(false),
      dialogTheme: _dialog(false),
      chipTheme: _chip(false),
      dividerColor: ZynkColors.lightBorder,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZynkColors.lightText,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.md)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────

class ZynkButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool outlined;
  final IconData? icon;
  final Color? bgColor;
  final double height;

  const ZynkButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.outlined = false,
    this.icon,
    this.bgColor,
    this.height = 52,
  });

  @override
  State<ZynkButton> createState() => _ZynkButtonState();
}

class _ZynkButtonState extends State<ZynkButton> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.bgColor ?? ZynkColors.primary;
    if (widget.outlined) {
      return SizedBox(
        width: double.infinity,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            child: child,
          ),
          child: OutlinedButton(
            onPressed: widget.isLoading ? null : widget.onTap,
            onHover: (hovering) {
              if (hovering) { _anim.forward(); } else { _anim.reverse(); }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: c,
              side: BorderSide(color: c.withValues(alpha: 0.6), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZynkRadius.lg),
              ),
              backgroundColor: c.withValues(alpha: 0.06),
            ),
            child: _inner(c),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.isLoading
                ? null
                : LinearGradient(
                    colors: [c, Color.lerp(c, Colors.black, 0.22)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: widget.isLoading ? c.withValues(alpha: 0.4) : null,
            borderRadius: BorderRadius.circular(ZynkRadius.lg),
            boxShadow: widget.isLoading
                ? null
                : [
                    BoxShadow(
                      color: c.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: c.withValues(alpha: 0.10),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
          ),
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onTap,
            onHover: (hovering) {
              if (hovering) { _anim.forward(); } else { _anim.reverse(); }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZynkRadius.lg),
              ),
            ),
            child: _inner(Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _inner(Color c) {
    if (widget.isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: c),
      );
    }
    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 18, color: c),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      );
    }
    return Text(
      widget.label,
      style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 15),
    );
  }
}

/// Helper: use AnimatedBuilder pattern (Flutter 3.x compat)
/// NOTE: We use Flutter's built-in AnimatedBuilder directly.
/// The ZynkButton references it as `AnimatedBuilder` from material.dart.

class CategoryBadge extends StatelessWidget {
  final String category;
  const CategoryBadge(this.category, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = ZynkColors.forCategory(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ZynkRadius.pill),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          color: c,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class ZynkDivider extends StatelessWidget {
  final String? label;
  const ZynkDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = dark ? ZynkColors.darkBorder : ZynkColors.lightBorder;
    if (label == null) return Divider(color: c, height: 1);
    return Row(
      children: [
        Expanded(child: Divider(color: c)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label!,
            style: TextStyle(
              color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Divider(color: c)),
      ],
    );
  }
}

/// Glass-morphism container used across the app
class ZynkGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;

  const ZynkGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = ZynkRadius.xl,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding ?? const EdgeInsets.all(ZynkSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.06),
            ),
            boxShadow: ZynkShadows.card,
          ),
          child: child,
        ),
      ),
    );
  }
}
