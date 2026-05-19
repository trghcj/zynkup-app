import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_bottom_nav.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/features/auth/screens/guest_home_screen.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
import 'package:zynkup/features/feed/screens/create_post_screen.dart';
import 'package:zynkup/features/clubs/screens/create_club_screen.dart';
import 'package:zynkup/features/home/tabs/home_tab.dart';
import 'package:zynkup/features/home/tabs/my_events_tab.dart';
import 'package:zynkup/features/profile/screens/profile_screen.dart';
import 'package:zynkup/features/feed/screens/feed_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _tabs = const [
    FeedTab(),
    HomeTab(), // Acts as Discover
    SizedBox.shrink(), // Create
    MyEventsTab(), // Tickets
    ProfileScreen(),
  ];

  Future<void> _create() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: ZynkColors.darkBg.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(top: BorderSide(color: ZynkColors.darkBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZynkColors.darkMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create New',
                style: TextStyle(
                  color: ZynkColors.offWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose what you want to share with the campus.',
                style: TextStyle(color: ZynkColors.darkMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              _CreationHubItem(
                icon: Icons.add_comment_rounded,
                title: 'Share a Post',
                subtitle: 'Post updates, photos, or banner highlights to feed',
                gradient: ZynkGradients.forCategory('sports'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                  ).then((value) {
                    if (value == true) {
                      setState(() => _index = 0);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _CreationHubItem(
                icon: Icons.event_rounded,
                title: 'Host an Event',
                subtitle: 'Organize workshops, seminars, or cultural meets',
                gradient: ZynkGradients.forCategory('tech'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                  ).then((value) {
                    setState(() => _index = 3);
                  });
                },
              ),
              const SizedBox(height: 12),
              _CreationHubItem(
                icon: Icons.groups_rounded,
                title: 'Found a Club',
                subtitle: 'Build a student community around shared passions',
                gradient: ZynkGradients.forCategory('cultural'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateClubScreen()),
                  ).then((value) {
                    if (value == true) {
                      setState(() => _index = 1);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _change(int index) {
    if (index == 2) {
      _create();
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(
        title: const Text('Zynkup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign out',
            onPressed: () async {
              await ApiService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                // ignore: use_build_context_synchronously
                context,
                MaterialPageRoute(builder: (_) => const GuestHomeScreen()),
                (_) => false,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: ZynkBottomNav(
        currentIndex: _index,
        onChanged: _change,
      ),
    );
  }
}

class _CreationHubItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _CreationHubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ZynkColors.darkSurface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(ZynkRadius.lg),
          border: Border.all(color: ZynkColors.darkBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ZynkColors.offWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: ZynkColors.darkMuted.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: ZynkColors.darkMuted),
          ],
        ),
      ),
    );
  }
}
