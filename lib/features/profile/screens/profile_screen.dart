// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/profile/widgets/dice_bear_avatar.dart';
import 'package:zynkup/features/profile/widgets/activity_heatmap.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  Map<String, int> _heatmapData = {};
  bool _loading = true;

  late TabController _tabController;

  final _nameC = TextEditingController();
  final _bioC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameC.dispose();
    _bioC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getCurrentUser(force: true),
        ApiService.getHeatmapData(),
      ]);
      final user = results[0];
      final heatmap = results[1] as Map<String, int>;
      
      if (mounted) {
        setState(() {
          _user = user;
          _heatmapData = heatmap;
          _loading = false;
          if (user != null) {
            _nameC.text = user['name'] ?? '';
            _bioC.text = user['bio'] ?? '';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _randomizeAvatar() async {
    final newSeed = DateTime.now().millisecondsSinceEpoch.toString();
    await ApiService.updateProfile(avatarSeed: newSeed);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ZynkColors.primary));
    }

    final user = _user ?? {};
    final xp = user['xp'] ?? 0;
    final level = user['level'] ?? 1;
    final streak = user['streak'] ?? 0;
    final theme = user['theme'] ?? 'midnight_orange';
    final seed = user['avatar_seed'] ?? user['email'] ?? 'default';
    final avatarType = user['avatar_type'] ?? 'rings';
    
    // Level progress calculation
    final currentLevelXP = (level - 1) * (level - 1) * 25;
    final nextLevelXP = level * level * 25;
    final progress = (xp - currentLevelXP) / (nextLevelXP - currentLevelXP);

    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── Hero Profile Header ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: ZynkColors.darkBg,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: ZynkGradients.forTheme(theme),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ZynkColors.darkBg.withValues(alpha: 0.1),
                          ZynkColors.darkBg,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Column(
                      children: [
                        // Avatar with Level Ring
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // XP Ring
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: CircularProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  strokeWidth: 8,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ZynkColors.primary,
                                  ),
                                ),
                              ),
                              // Avatar
                              GestureDetector(
                                onTap: _randomizeAvatar,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: ClipOval(
                                    child: DiceBearAvatar(
                                      seed: seed,
                                      type: avatarType,
                                      size: 100,
                                    ),
                                  ),
                                ),
                              ),
                              // Level Badge
                              Positioned(
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ZynkColors.primary,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black45, blurRadius: 4),
                                    ],
                                  ),
                                  child: Text(
                                    'Lvl $level',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          user['name'] ?? 'Student',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        
                        Text(
                          '@${user['email']?.split('@')[0] ?? 'user'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Streak + XP Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _InfoPill(
                              icon: Icons.local_fire_department_rounded,
                              label: '$streak day streak',
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 10),
                            _InfoPill(
                              icon: Icons.bolt_rounded,
                              label: '$xp XP',
                              color: ZynkColors.accent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Progression Bar (Sticky) ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Level $level',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$xp/$nextLevelXP XP',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(ZynkColors.primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Next unlock: Neon Avatar at Lvl 5',
                    style: TextStyle(color: ZynkColors.darkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          // ── Stats Grid ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _StatCard(label: 'Events', value: '${user['events_created'] ?? 0}', icon: Icons.event_rounded),
                _StatCard(label: 'Attended', value: '${user['attended'] ?? 0}', icon: Icons.check_circle_rounded),
                _StatCard(label: 'Rank', value: '#${(1000 - level * 10).clamp(1, 1000)}', icon: Icons.emoji_events_rounded),
              ],
            ),
          ),

          // ── Tabs ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: TabBar(
              controller: _tabController,
              indicatorColor: ZynkColors.primary,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white30,
              onTap: (index) => setState(() {}),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Events'),
                Tab(text: 'Badges'),
              ],
            ),
          ),

          // ── Tab Content ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverToBoxAdapter(
              child: [
                _OverviewTab(user: user, heatmapData: _heatmapData),
                _EventsTab(user: user),
                _BadgesTab(user: user),
              ][_tabController.index],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: ZynkColors.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, int> heatmapData;
  const _OverviewTab({required this.user, required this.heatmapData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bio',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            user['bio']?.isNotEmpty == true ? user['bio'] : 'No bio set yet.',
            style: const TextStyle(color: ZynkColors.darkMuted),
          ),
          const SizedBox(height: 24),
          const Text(
            'Achievements',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _BadgeIcon(icon: Icons.star_rounded, label: 'First Event', color: Colors.amber),
                _BadgeIcon(icon: Icons.bolt_rounded, label: '5 Streak', color: Colors.orange),
                _BadgeIcon(icon: Icons.group_rounded, label: 'Organizer', color: Colors.blue),
                _BadgeIcon(icon: Icons.verified_rounded, label: 'Verified', color: Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Activity Heatmap',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ActivityHeatmap(data: heatmapData),
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BadgeIcon({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _EventsTab extends StatelessWidget {
  final Map<String, dynamic> user;
  const _EventsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text('No events found', style: TextStyle(color: ZynkColors.darkMuted)),
      ),
    );
  }
}

class _BadgesTab extends StatelessWidget {
  final Map<String, dynamic> user;
  const _BadgesTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text('Coming Soon', style: TextStyle(color: ZynkColors.darkMuted)),
      ),
    );
  }
}
