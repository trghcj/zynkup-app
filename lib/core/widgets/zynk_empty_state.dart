import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class ZEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ZEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ZynkColors.darkSurface,
                shape: BoxShape.circle,
                border: Border.all(color: ZynkColors.darkBorder),
              ),
              child: Icon(icon, size: 48, color: ZynkColors.darkMuted),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: ZynkColors.offWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: ZynkColors.darkMuted,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: ZynkColors.darkSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: ZynkColors.darkBorder),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(color: ZynkColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
