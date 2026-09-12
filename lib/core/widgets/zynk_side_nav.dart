
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0F1217) : Theme.of(context).scaffoldBackgroundColor;
    final navBorder = isDark ? const Color(0xFF252B35) : Theme.of(context).colorScheme.outlineVariant;
    final activeColor = isDark ? ZynkColors.primary : const Color(0xFF65A30D);
    final inactiveColor = isDark
        ? const Color(0xFF737984)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: navBg,
        border: Border(
          right: BorderSide(color: navBorder),
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
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: selected && !isCreate
                    ? (isDark ? ZynkColors.primary.withValues(alpha: 0.1) : const Color(0xFFF7FEE7))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isCreate)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: ZynkColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33C7D437),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF1F242F),
                        size: 24,
                      ),
                    )
                  else ...[
                    Icon(
                      item.$1,
                      color: selected ? activeColor : inactiveColor,
                      size: 26,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? activeColor : inactiveColor,
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
