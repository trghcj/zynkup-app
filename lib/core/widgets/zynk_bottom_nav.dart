import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class ZynkBottomNav extends StatelessWidget {
  const ZynkBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.explore_rounded, 'Explore'),
    (Icons.add_circle_rounded, 'Create'),
    (Icons.event_available_rounded, 'My Events'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: ZynkColors.darkSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(ZynkRadius.xl),
          border: Border.all(
            color: ZynkColors.gold.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: ZynkColors.deepOlive.withValues(alpha: 0.15),
              blurRadius: 48,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = currentIndex == index;
            final isCreate = index == 2;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? (isCreate
                            ? ZynkColors.primary.withValues(alpha: 0.18)
                            : ZynkColors.gold.withValues(alpha: 0.10))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(ZynkRadius.lg),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        decoration: isCreate && selected
                            ? BoxDecoration(
                                color: ZynkColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: ZynkColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                  ),
                                ],
                              )
                            : null,
                        padding: isCreate
                            ? const EdgeInsets.all(6)
                            : EdgeInsets.zero,
                        child: Icon(
                          item.$1,
                          color: selected
                              ? (isCreate ? Colors.white : ZynkColors.gold)
                              : ZynkColors.darkMuted.withValues(alpha: 0.6),
                          size: isCreate ? 26 : 22,
                        ),
                      ),
                      if (!isCreate) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? ZynkColors.gold
                                : ZynkColors.darkMuted.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
