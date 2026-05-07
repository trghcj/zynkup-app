import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_bottom_nav.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
import 'package:zynkup/features/home/tabs/explore_tab.dart';
import 'package:zynkup/features/home/tabs/home_tab.dart';
import 'package:zynkup/features/home/tabs/my_events_tab.dart';
import 'package:zynkup/features/home/tabs/profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _tabs = const [
    HomeTab(),
    ExploreTab(),
    SizedBox.shrink(),
    MyEventsTab(),
    ProfileTab(),
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
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: ZynkBottomNav(
        currentIndex: _index,
        onChanged: _change,
      ),
    );
  }
}
