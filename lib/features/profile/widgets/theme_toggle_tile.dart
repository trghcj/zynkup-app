// lib/features/profile/widgets/theme_toggle_tile.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/theme_provider.dart';
import 'package:zynkup/core/theme/app_theme.dart';

/// A profile-page tile that lets the user switch Dark vs Light theme.
class ThemeToggleTile extends StatelessWidget {
  const ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: themeProvider,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
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
                    child: const Icon(Icons.palette_rounded,
                        color: ZynkColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Theme Mode',
                    style: TextStyle(
                        color: cs.onSurface, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SegmentedButton<AppThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_rounded, size: 16),
                  ),
                ],
                selected: {themeProvider.currentTheme},
                onSelectionChanged: (selection) =>
                    themeProvider.setTheme(selection.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? ZynkColors.darkSurface
                        : cs.onSurface.withValues(alpha: 0.5),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? ZynkColors.primary
                        : cs.surface,
                  ),
                  side: WidgetStateProperty.all(
                    BorderSide(color: cs.outlineVariant),
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
