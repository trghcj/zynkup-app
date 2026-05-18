import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/guest_home_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _analytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ApiService.getCurrentUser(force: true),
      ApiService.getPersonalAnalytics(),
    ]);
    if (!mounted) return;
    setState(() {
      _user = results[0];
      _analytics = results[1];
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GuestHomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (_user?['name'] ?? _user?['email'] ?? 'Zynkup user')
        .toString();
    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: ZynkColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ZynkColors.darkText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (_user?['email'] ?? '').toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ZynkColors.darkMuted),
                ),
                const SizedBox(height: 24),
                _StatsGrid(data: _analytics ?? const {}),
                const SizedBox(height: 20),
                ZynkButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  outlined: true,
                  onTap: _logout,
                ),
              ],
            ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Events', data['events_created'] ?? 0),
      ('Attended', data['attended'] ?? 0),
      ('Rank', '#${data['rank'] ?? 1}'),
      ('Students reached', data['total_attendees'] ?? 0),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (_, index) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ZynkColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZynkColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              items[index].$2.toString(),
              style: const TextStyle(
                color: ZynkColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              items[index].$1,
              style: const TextStyle(
                color: ZynkColors.darkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
