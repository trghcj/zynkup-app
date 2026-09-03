import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZynkColors {
  // ── Brand ────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFC7D437); // Zynkup Lime
  static const Color accent = Color(0xFFC7D437);
  static const Color secondaryAccent = Color(0xFF8B5CF6); // Purple
  static const Color info = Color(0xFF22C7D6); // Cyan
  static const Color warmAccent = Color(0xFFFF8A1F); // Orange

  // Legacy mappings for compatibility
  static const sand = Color(0xFFC7D437);
  static const gold = Color(0xFFC7D437);
  static const orange = Color(0xFFFF8A1F);
  static const warmBrown = Color(0xFF252B35);
  static const deepOlive = Color(0xFF1B2028);
  static const offWhite = Color(0xFFF4F5F7);
  static const primaryDark = Color(0xFFC7D437);
  static const primaryLight = Color(0xFFC7D437);
  static const accentLight = Color(0xFFC7D437);
  static Color get accentGlow => primary.withValues(alpha: 0.1);

  static const terra1 = warmAccent;
  static const terra2 = warmAccent;
  static const terra3 = warmAccent;

  // ── Dark surfaces ─────────────────────────────────────────────────
  static const darkBg = Color(0xFF090B0F);
  static const darkSurface = Color(0xFF12161C);
  static const darkSurface2 = Color(0xFF171C23);
  static const elevatedSurface = Color(0xFF1B2028);
  static const darkBorder = Color(0xFF252B35);
  static const darkText = Color(0xFFF4F5F7);
  static const darkMuted = Color(0xFF969DA8);

  // ── Light surfaces (mapped to dark for this redesign)
  static const lightBg = darkBg;
  static const lightSurface = darkSurface;
  static const lightSurf2 = darkSurface2;
  static const lightBorder = darkBorder;
  static const lightText = darkText;
  static const lightMuted = darkMuted;

  // ── Semantic ──────────────────────────────────────────────────────
  static const success = Color(0xFFC7D437);
  static const error = Color(0xFFE53935);
  static const warning = Color(0xFFFF8A1F);

  // ── Category ─────────────────────────────────────────────────────
  static Color forCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'tech': return info;
      case 'cultural': return secondaryAccent;
      case 'sports': return primary;
      case 'workshop': return warmAccent;
      case 'seminar': return secondaryAccent;
      default: return darkSurface2;
    }
  }
}

class ZynkGradients {
  static const brand = LinearGradient(
    colors: [ZynkColors.primary, ZynkColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warmDark = LinearGradient(
    colors: [ZynkColors.darkBg, ZynkColors.darkBg],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const cardSurface = LinearGradient(
    colors: [ZynkColors.darkSurface, ZynkColors.darkSurface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldShimmer = LinearGradient(
    colors: [ZynkColors.primary, ZynkColors.primary, ZynkColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const buttonPrimary = LinearGradient(
    colors: [ZynkColors.primary, ZynkColors.primary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const gold = LinearGradient(
    colors: [ZynkColors.primary, ZynkColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient forCategory(String cat) {
    return LinearGradient(
      colors: [ZynkColors.forCategory(cat), ZynkColors.forCategory(cat)],
    );
  }

  static LinearGradient forTheme(String theme) {
    return brand;
  }
}

class ZynkSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class ZynkRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 14.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

class ZynkShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> button = [];
  static List<BoxShadow> nav = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 10,
      offset: const Offset(0, -2),
    ),
  ];
  static List<BoxShadow> glow(Color color) => [];
  static List<BoxShadow> categoryGlow(String category) => [];
}

class AppTheme {
  static InputDecorationTheme _input(bool dark) => InputDecorationTheme(
    filled: true,
    fillColor: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      borderRadius: BorderRadius.circular(ZynkRadius.md),
      borderSide: const BorderSide(color: ZynkColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.md),
      borderSide: const BorderSide(color: ZynkColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.md),
      borderSide: const BorderSide(color: ZynkColors.error, width: 1.5),
    ),
    labelStyle: TextStyle(
      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
      fontWeight: FontWeight.w400,
    ),
    hintStyle: TextStyle(
      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
    ),
    prefixIconColor: ZynkColors.darkMuted,
    suffixIconColor: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
  );

  static CardThemeData _card(bool dark) => CardThemeData(
    color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.xl),
      side: BorderSide(
        color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
        width: 1,
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
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    iconTheme: IconThemeData(color: dark ? ZynkColors.darkText : ZynkColors.lightText, size: 22),
    actionsIconTheme: IconThemeData(color: dark ? ZynkColors.darkText : ZynkColors.lightText, size: 22),
  );

  static ElevatedButtonThemeData get _btn => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: ZynkColors.primary,
      foregroundColor: ZynkColors.darkSurface,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.lg)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    ),
  );

  static OutlinedButtonThemeData get _outlineBtn => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ZynkColors.primary,
      side: const BorderSide(color: ZynkColors.darkBorder, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.lg)),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    ),
  );

  static TextButtonThemeData get _textBtn => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: ZynkColors.primary,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.md)),
    ),
  );

  static TabBarThemeData _tabBar(bool dark) => TabBarThemeData(
    indicatorColor: ZynkColors.primary,
    indicatorSize: TabBarIndicatorSize.label,
    labelColor: dark ? ZynkColors.primary : ZynkColors.primary,
    unselectedLabelColor: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
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
      fontWeight: FontWeight.w600,
    ),
    contentTextStyle: TextStyle(
      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
      fontSize: 14,
      height: 1.5,
    ),
  );

  static ChipThemeData _chip(bool dark) => ChipThemeData(
    backgroundColor: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
    selectedColor: ZynkColors.elevatedSurface,
    labelStyle: TextStyle(
      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
      fontWeight: FontWeight.w400,
      fontSize: 13,
    ),
    secondaryLabelStyle: const TextStyle(
      color: ZynkColors.primary,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZynkRadius.sm),
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
      textTheme: GoogleFonts.interTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.inter(textStyle: baseTextTheme.displayLarge, fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.inter(textStyle: baseTextTheme.displayMedium, fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.inter(textStyle: baseTextTheme.displaySmall, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.inter(textStyle: baseTextTheme.headlineLarge, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.inter(textStyle: baseTextTheme.headlineMedium, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.inter(textStyle: baseTextTheme.headlineSmall, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(textStyle: baseTextTheme.titleLarge, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(textStyle: baseTextTheme.titleMedium, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(textStyle: baseTextTheme.titleSmall, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(textStyle: baseTextTheme.bodyLarge, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(textStyle: baseTextTheme.bodyMedium, fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.inter(textStyle: baseTextTheme.bodySmall, fontWeight: FontWeight.w400),
      ),
      colorScheme: const ColorScheme.dark(
        primary: ZynkColors.primary,
        secondary: ZynkColors.secondaryAccent,
        surface: ZynkColors.darkSurface,
        error: ZynkColors.error,
        onPrimary: ZynkColors.darkSurface,
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
        contentTextStyle: const TextStyle(color: ZynkColors.darkText, fontWeight: FontWeight.w400),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZynkRadius.md),
          side: const BorderSide(color: ZynkColors.darkBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return ZynkColors.darkSurface2;
            return ZynkColors.darkBg;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return ZynkColors.primary;
            return ZynkColors.darkMuted;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: ZynkColors.darkBorder),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZynkRadius.md)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }

  static ThemeData get light => dark; // Forces dark theme for simplicity in this exercise, as instructed.
}

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
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            foregroundColor: ZynkColors.darkText,
            side: const BorderSide(color: ZynkColors.darkBorder, width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZynkRadius.lg),
            ),
          ),
          child: _inner(ZynkColors.darkText),
        ),
      );
    }
    final c = bgColor ?? ZynkColors.primary;
    final tc = (c == ZynkColors.primary || c == ZynkColors.info || c == ZynkColors.warmAccent) ? ZynkColors.darkSurface : Colors.white;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: c,
          foregroundColor: tc,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZynkRadius.lg),
          ),
        ),
        child: _inner(tc),
      ),
    );
  }

  Widget _inner(Color c) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: c),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      );
    }
    return Text(
      label,
      style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}

class CategoryBadge extends StatelessWidget {
  final String category;
  const CategoryBadge(this.category, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface2,
        borderRadius: BorderRadius.circular(ZynkRadius.sm),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: ZynkColors.darkMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
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
    const c = ZynkColors.darkBorder;
    if (label == null) return const Divider(color: c, height: 1);
    return Row(
      children: [
        const Expanded(child: Divider(color: c)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label!,
            style: const TextStyle(
              color: ZynkColors.darkMuted,
              fontSize: 12,
            ),
          ),
        ),
        const Expanded(child: Divider(color: c)),
      ],
    );
  }
}

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
    return Container(
      padding: padding ?? const EdgeInsets.all(ZynkSpacing.md),
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? ZynkColors.darkBorder,
          width: 1,
        ),
        boxShadow: ZynkShadows.card,
      ),
      child: child,
    );
  }
}
