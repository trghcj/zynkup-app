import 'dart:ui';
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
    (Icons.add_circle_rounded, 'Create'),
    (Icons.event_available_rounded, 'Tickets'),
    (Icons.person_rounded, 'Profile'),
  ];



  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ZynkRadius.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(ZynkRadius.xl),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
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
                              padding: EdgeInsets.all(isCreate ? 8 : 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCreate
                                    ? (selected
                                        ? ZynkColors.primary
                                        : Colors.white.withValues(alpha: 0.15))
                                    : Colors.transparent,
                              ),
                              child: Icon(
                                item.$1,
                                size: isCreate ? 26 : 24,
                                color: isCreate
                                    ? Colors.white
                                    : selected
                                        ? ZynkColors.gold
                                        : Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            if (!isCreate) ...[
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      selected ? FontWeight.w600 : FontWeight.w500,
                                  color: selected
                                      ? ZynkColors.gold
                                      : Colors.white.withValues(alpha: 0.35),
                                ),
                                child: Text(item.$2),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
