import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_bottom_nav.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/features/auth/screens/guest_home_screen.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateEventScreen()),
    );
    if (mounted) setState(() => _index = 3);
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
