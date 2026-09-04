
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
      decoration: const BoxDecoration(
        color: Color(0xFF0F1217),
        border: Border(
          right: BorderSide(color: Color(0xFF252B35)),
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
                    ? ZynkColors.primary.withValues(alpha: 0.1)
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
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: ZynkColors.darkSurface,
                        size: 24,
                      ),
                    )
                  else ...[
                    Icon(
                      item.$1,
                      color: selected
                          ? ZynkColors.primary
                          : const Color(0xFF737984),
                      size: 26,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? ZynkColors.primary
                            : const Color(0xFF737984),
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
