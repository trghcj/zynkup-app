import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/home/screens/home_screen.dart';
import 'package:zynkup/features/profile/widgets/dice_bear_avatar.dart';

class AvatarGalleryScreen extends StatelessWidget {
  final int currentLevel;
  const AvatarGalleryScreen({super.key, required this.currentLevel});

  static const _categories = [
    (1, 'Rings', 'rings', 'The standard adventurer set. Sharp and clean.'),
    (5, 'Neon', 'neon', 'Cybernetic bottts for the tech-savvy student.'),
    (10, 'Cyberpunk', 'cyberpunk', 'Neo-tokyo vibes. Glitchy and stylish.'),
    (15, 'Anime', 'anime', 'Pixel-art style for the otaku in you.'),
    (20, 'Elite', 'space', 'The ultimate big-smile space explorer set.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(
        title: const Text('Avatar Gallery'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () async {
              await ApiService.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Unlock Tiers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Level up by creating events, attending, and engaging with the community to unlock new avatar styles.',
            style: TextStyle(color: ZynkColors.darkMuted),
          ),
          const SizedBox(height: 32),
          ..._categories.map((cat) {
            final locked = currentLevel < cat.$1;
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZynkColors.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: locked ? Colors.white10 : ZynkColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipOval(
                        child: ColorFiltered(
                          colorFilter: locked
                              ? const ColorFilter.matrix([
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0,      0,      0,      1, 0,
                                ])
                              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                          child: DiceBearAvatar(
                            seed: 'gallery-${cat.$3}',
                            type: cat.$3,
                            size: 80,
                          ),
                        ),
                      ),
                      if (locked)
                        const Positioned.fill(
                          child: Center(
                            child: Icon(Icons.lock_rounded, color: Colors.white70, size: 30),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cat.$2,
                              style: TextStyle(
                                color: locked ? Colors.white30 : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: locked ? Colors.white10 : ZynkColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Lvl ${cat.$1}',
                                style: TextStyle(
                                  color: locked ? Colors.white24 : ZynkColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cat.$4,
                          style: TextStyle(
                            color: locked ? Colors.white12 : ZynkColors.darkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
