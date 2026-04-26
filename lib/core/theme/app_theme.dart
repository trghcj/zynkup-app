// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
//  ZYNKUP — Warm/Earthy Design System
//  Palette: Burnt orange · Terracotta · Gold · Charcoal · Cream
// ═══════════════════════════════════════════════════════════════════

class ZynkColors {
  // ── Brand ────────────────────────────────────────────────────────
  static const primary      = Color(0xFFE05C2A);
  static const primaryDark  = Color(0xFFC44A1C);
  static const primaryLight = Color(0xFFFF8055);
  static const accent       = Color(0xFFD4A017);
  static const accentLight  = Color(0xFFF0C840);

  // ── Terracotta ────────────────────────────────────────────────────
  static const terra1       = Color(0xFFB5451B);
  static const terra2       = Color(0xFFD4622E);
  static const terra3       = Color(0xFFE8875A);

  // ── Dark surfaces ─────────────────────────────────────────────────
  static const darkBg       = Color(0xFF18120E);
  static const darkSurface  = Color(0xFF221A14);
  static const darkSurface2 = Color(0xFF2D231C);
  static const darkBorder   = Color(0xFF3C2E24);
  static const darkText     = Color(0xFFF5EDE4);
  static const darkMuted    = Color(0xFF9C8878);

  // ── Light surfaces ────────────────────────────────────────────────
  static const lightBg      = Color(0xFFFAF6F1);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurf2   = Color(0xFFF5EDE4);
  static const lightBorder  = Color(0xFFE8D8CC);
  static const lightText    = Color(0xFF2A1F18);
  static const lightMuted   = Color(0xFF8A7060);

  // ── Semantic ──────────────────────────────────────────────────────
  static const success      = Color(0xFF4CAF7D);
  static const error        = Color(0xFFE53935);
  static const warning      = Color(0xFFFFB300);

  // ── Category ─────────────────────────────────────────────────────
  static const catTech      = Color(0xFF5C9EE8);
  static const catCultural  = Color(0xFFD4A017);
  static const catSports    = Color(0xFF4CAF7D);
  static const catWorkshop  = Color(0xFFE05C2A);
  static const catSeminar   = Color(0xFF9C6FBF);

  static Color forCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'tech':     return catTech;
      case 'cultural': return catCultural;
      case 'sports':   return catSports;
      case 'workshop': return catWorkshop;
      case 'seminar':  return catSeminar;
      default:         return primary;
    }
  }
}

class ZynkGradients {
  static const brand = LinearGradient(
    colors: [ZynkColors.primaryDark, ZynkColors.primary, ZynkColors.terra3],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warmDark = LinearGradient(
    colors: [Color(0xFF18120E), Color(0xFF2D1E14)],
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
        return const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF5C9EE8)]);
      case 'cultural':
        return const LinearGradient(colors: [Color(0xFF5A3E00), Color(0xFFD4A017)]);
      case 'sports':
        return const LinearGradient(colors: [Color(0xFF1A3D2B), Color(0xFF4CAF7D)]);
      case 'workshop':
        return const LinearGradient(colors: [ZynkColors.primaryDark, ZynkColors.terra3]);
      case 'seminar':
        return const LinearGradient(colors: [Color(0xFF3D1A5F), Color(0xFF9C6FBF)]);
      default:
        return brand;
    }
  }
}

class AppTheme {
  static InputDecorationTheme _input(bool dark) => InputDecorationTheme(
        filled: true,
        fillColor: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ZynkColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ZynkColors.error),
        ),
        labelStyle: TextStyle(
            color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
        prefixIconColor: ZynkColors.primary,
        suffixIconColor:
            dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
      );

  static CardThemeData _card(bool dark) => CardThemeData(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        elevation: dark ? 0 : 1,
        shadowColor: ZynkColors.primary.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
        ),
      );

  static AppBarTheme _appBar(bool dark) => AppBarTheme(
        backgroundColor: dark ? ZynkColors.darkSurface : ZynkColors.lightBg,
        foregroundColor: dark ? ZynkColors.darkText : ZynkColors.lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: dark ? ZynkColors.darkText : ZynkColors.lightText,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: ZynkColors.primary, size: 22),
        actionsIconTheme:
            const IconThemeData(color: ZynkColors.primary, size: 22),
      );

  static ElevatedButtonThemeData get _btn => ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZynkColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
        ),
      );

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
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
        dividerColor: ZynkColors.darkBorder,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: ZynkColors.darkSurface2,
          contentTextStyle: const TextStyle(color: ZynkColors.darkText),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
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
        dividerColor: ZynkColors.lightBorder,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: ZynkColors.lightText,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
}

// ── Shared Widgets ────────────────────────────────────────────────

class ZynkButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = bgColor ?? ZynkColors.primary;
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: c,
            side: BorderSide(color: c, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _inner(c),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : LinearGradient(
                  colors: [c, Color.lerp(c, Colors.black, 0.18)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isLoading ? c.withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isLoading
              ? null
              : [BoxShadow(color: c.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _inner(Colors.white),
        ),
      ),
    );
  }

  Widget _inner(Color c) {
    if (isLoading) {
      return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: c));
    }
    if (icon != null) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: c, fontWeight: FontWeight.w700, fontSize: 15)),
      ]);
    }
    return Text(label,
        style: TextStyle(
            color: c, fontWeight: FontWeight.w700, fontSize: 15));
  }
}

class CategoryBadge extends StatelessWidget {
  final String category;
  const CategoryBadge(this.category, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = ZynkColors.forCategory(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
            color: c,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8),
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
    return Row(children: [
      Expanded(child: Divider(color: c)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label!,
            style: TextStyle(
                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                fontSize: 12)),
      ),
      Expanded(child: Divider(color: c)),
    ]);
  }
}