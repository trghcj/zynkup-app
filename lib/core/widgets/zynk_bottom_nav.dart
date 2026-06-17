import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:zynkup/core/utils/showcase_keys.dart';

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

  GlobalKey _getShowcaseKey(int index) {
    switch (index) {
      case 0: return ShowcaseKeys.homeTab;
      case 1: return ShowcaseKeys.discoverTab;
      case 2: return ShowcaseKeys.createFab;
      case 3: return ShowcaseKeys.ticketsTab;
      case 4: return ShowcaseKeys.profileTab;
      default: return GlobalKey();
    }
  }

  String _getShowcaseDescription(int index) {
    switch (index) {
      case 0: return 'See posts from campus and interact with them.';
      case 1: return 'Discover upcoming events and new clubs.';
      case 2: return 'Host events, create clubs, or share a post from here.';
      case 3: return 'View your registered events and tickets.';
      case 4: return 'Manage your profile, badges, and avatar.';
      default: return '';
    }
  }

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
                    child: Showcase(
                      key: _getShowcaseKey(index),
                      title: _items[index].$2,
                      description: _getShowcaseDescription(index),
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
                                    ? const EdgeInsets.all(6)
                                    : EdgeInsets.zero,
                                child: Icon(
                                  item.$1,
                                  color: isCreate
                                      ? Colors.white
                                      : (selected
                                          ? ZynkColors.gold
                                          : ZynkColors.darkMuted.withValues(alpha: 0.6)),
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
