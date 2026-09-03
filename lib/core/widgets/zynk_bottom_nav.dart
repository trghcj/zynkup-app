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
    (Icons.dynamic_feed_rounded, 'Feed'),
    (Icons.explore_rounded, 'Discover'),
    (Icons.add_rounded, 'Create'), // changed icon for cleaner look
    (Icons.event_available_rounded, 'Tickets'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1217),
        border: Border(top: BorderSide(color: Color(0xFF252B35), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = currentIndex == index;
              final isCreate = index == 2;
              
              if (isCreate) {
                return GestureDetector(
                  onTap: () => onChanged(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ZynkColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: ZynkColors.darkSurface,
                      size: 24,
                    ),
                  ),
                );
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$1,
                        color: selected
                            ? ZynkColors.primary
                            : const Color(0xFF737984),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? ZynkColors.primary
                              : const Color(0xFF737984),
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
