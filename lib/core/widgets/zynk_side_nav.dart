
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class ZynkSideNav extends StatelessWidget {
  const ZynkSideNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.dynamic_feed_rounded, 'Feed'),
    (Icons.explore_rounded, 'Discover'),
    (Icons.add_circle_rounded, 'Create'),
    (Icons.event_available_rounded, 'Tickets'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface.withValues(alpha: 0.3),
        border: const Border(
          right: BorderSide(color: ZynkColors.darkBorder),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final selected = currentIndex == index;
          final isCreate = index == 2;
          
          return GestureDetector(
            onTap: () => onChanged(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                    decoration: isCreate
                        ? BoxDecoration(
                            color: selected
                                ? ZynkColors.primary
                                : Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: ZynkColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          )
                        : null,
                    padding: isCreate
                        ? const EdgeInsets.all(10)
                        : EdgeInsets.zero,
                    child: Icon(
                      item.$1,
                      color: isCreate
                          ? Colors.white
                          : (selected
                              ? ZynkColors.gold
                              : ZynkColors.darkMuted.withValues(alpha: 0.6)),
                      size: isCreate ? 28 : 26,
                    ),
                  ),
                  if (!isCreate) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? ZynkColors.gold
                            : ZynkColors.darkMuted.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
