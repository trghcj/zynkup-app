// lib/features/profile/widgets/theme_toggle_tile.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/theme_provider.dart';
import 'package:zynkup/core/theme/app_theme.dart';

/// A widget that allows the user to toggle between Dark, Light, and System theme modes.
class ThemeToggleTile extends StatelessWidget {
  const ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeProvider,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZynkColors.darkSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZynkColors.darkBorder),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZynkColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.palette_rounded, color: ZynkColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Theme Mode',
                    style: TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SegmentedButton<AppThemeMode>(
                segments: const [
                  ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
                  ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: AppThemeMode.system, label: Text('System')),
                ],
                selected: {themeProvider.currentTheme},
                onSelectionChanged: (selection) => themeProvider.setTheme(selection.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? ZynkColors.darkBg : ZynkColors.darkMuted,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? ZynkColors.gold : ZynkColors.darkSurface,
                  ),
                  side: WidgetStateProperty.all(
                    BorderSide(color: ZynkColors.darkBorder.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
