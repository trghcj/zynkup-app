// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/profile/widgets/dice_bear_avatar.dart';
import 'package:zynkup/features/profile/widgets/activity_heatmap.dart';
import 'package:zynkup/features/profile/screens/avatar_gallery_screen.dart';

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
    final email = user['email'] ?? 'user@zynkup.com';
    final seed = user['avatar_seed'] ?? email;
    final avatarType = user['avatar_type'] ?? 'rings';
    
    // Level progress calculation
    int nextLevelXP = level * level * 25;
    int currentLevelXP = (level - 1) * (level - 1) * 25;
    
    // Fallback for edge cases
    if (nextLevelXP <= currentLevelXP) nextLevelXP = currentLevelXP + 25;
    
    double progress = (xp - currentLevelXP) / (nextLevelXP - currentLevelXP);
    if (progress.isNaN || progress.isInfinite) progress = 0.0;

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
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AvatarGalleryScreen(currentLevel: level),
                ),
              ),
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
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Next unlock: Neon Avatar at Lvl 5',
                          style: TextStyle(color: ZynkColors.darkMuted, fontSize: 11),
                        ),
                        Text(
                          'View Gallery →',
                          style: TextStyle(color: ZynkColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Stats Grid ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              delegate: SliverChildListDelegate.fixed(
                [
                  _StatCard(
                    label: 'Events',
                    value: '${user['events_created'] ?? 0}',
                    icon: Icons.event_rounded,
                  ),
                  _StatCard(
                    label: 'Attended',
                    value: '${user['attended'] ?? 0}',
                    icon: Icons.check_circle_rounded,
                  ),
                  _StatCard(
                    label: 'Rank',
                    value: '#${user['rank'] ?? 1}',
                    icon: Icons.emoji_events_rounded,
                  ),
                ],
              ),
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
    final unlockedBadges = _profileBadges(user)
        .where((badge) => badge.unlocked)
        .take(5)
        .toList();
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
            child: unlockedBadges.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Earn your first badge by joining or creating an event.',
                      style: TextStyle(color: ZynkColors.darkMuted),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: unlockedBadges.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, index) {
                      final badge = unlockedBadges[index];
                      return _BadgeIcon(badge: badge);
                    },
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
  final _ProfileBadge badge;

  const _BadgeIcon({required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = badge.unlocked ? badge.color : ZynkColors.darkMuted;
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: badge.unlocked ? 0.16 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: badge.unlocked ? 0.55 : 0.2),
                    width: 1.5,
                  ),
                  boxShadow: badge.unlocked
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.18),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: badge.unlocked
                      ? color.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(badge.icon, color: color, size: 22),
              ),
              if (!badge.unlocked)
                const Positioned(
                  right: 10,
                  bottom: 8,
                  child: Icon(
                    Icons.lock_rounded,
                    color: ZynkColors.darkMuted,
                    size: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            badge.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: badge.unlocked ? ZynkColors.darkText : ZynkColors.darkMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
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
    final badges = _profileBadges(user);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: badges.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.86,
        ),
        itemBuilder: (_, index) => _BadgeTile(badge: badges[index]),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final _ProfileBadge badge;

  @override
  Widget build(BuildContext context) {
    final color = badge.unlocked ? badge.color : ZynkColors.darkMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badge.unlocked
              ? color.withValues(alpha: 0.45)
              : ZynkColors.darkBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgeIcon(badge: badge),
          const SizedBox(height: 12),
          Text(
            badge.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: badge.unlocked
                  ? ZynkColors.darkMuted
                  : ZynkColors.darkMuted.withValues(alpha: 0.72),
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBadge {
  const _ProfileBadge({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
}

List<_ProfileBadge> _profileBadges(Map<String, dynamic> user) {
  final raw = user['badges'];
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map(
          (item) => _ProfileBadge(
            name: (item['name'] ?? '').toString(),
            description: (item['description'] ?? '').toString(),
            icon: _badgeIcon((item['icon'] ?? '').toString()),
            color: _badgeColor((item['color'] ?? '').toString()),
            unlocked: item['unlocked'] == true,
          ),
        )
        .where((badge) => badge.name.isNotEmpty)
        .toList();
  }
  return const [
    _ProfileBadge(
      name: 'First Event',
      description: 'Register for your first event.',
      icon: Icons.event_available_rounded,
      color: Color(0xFFF97316),
      unlocked: false,
    ),
    _ProfileBadge(
      name: 'Explorer',
      description: 'Register for 3 events.',
      icon: Icons.explore_rounded,
      color: Color(0xFF38BDF8),
      unlocked: false,
    ),
    _ProfileBadge(
      name: 'First Creator',
      description: 'Create your first event.',
      icon: Icons.add_circle_rounded,
      color: Color(0xFFA78BFA),
      unlocked: false,
    ),
    _ProfileBadge(
      name: 'Rising Star',
      description: 'Reach level 3.',
      icon: Icons.star_rounded,
      color: Color(0xFFFACC15),
      unlocked: false,
    ),
    _ProfileBadge(
      name: 'Community Hero',
      description: 'Attend 5 events.',
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFF22C55E),
      unlocked: false,
    ),
    _ProfileBadge(
      name: '7-Day Streak',
      description: 'Keep a 7-day activity streak.',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFEF4444),
      unlocked: false,
    ),
    _ProfileBadge(
      name: 'Verified Organizer',
      description: 'Become an organizer or admin.',
      icon: Icons.verified_rounded,
      color: Color(0xFF14B8A6),
      unlocked: false,
    ),
    _ProfileBadge(
      name: 'Founding Member',
      description: 'Be among the first 100 Zynkup members.',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFFB7185),
      unlocked: false,
    ),
    _ProfileBadge(
      name: 'Crowd Magnet',
      description: 'Bring 10 total attendees to your events.',
      icon: Icons.groups_rounded,
      color: Color(0xFF60A5FA),
      unlocked: false,
    ),
    _ProfileBadge(
      name: 'Elite Member',
      description: 'Reach level 10.',
      icon: Icons.military_tech_rounded,
      color: Color(0xFFF59E0B),
      unlocked: false,
    ),
  ];
}

IconData _badgeIcon(String icon) {
  switch (icon) {
    case 'event_available':
      return Icons.event_available_rounded;
    case 'explore':
      return Icons.explore_rounded;
    case 'add_circle':
      return Icons.add_circle_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'volunteer_activism':
      return Icons.volunteer_activism_rounded;
    case 'local_fire_department':
      return Icons.local_fire_department_rounded;
    case 'verified':
      return Icons.verified_rounded;
    case 'workspace_premium':
      return Icons.workspace_premium_rounded;
    case 'groups':
      return Icons.groups_rounded;
    case 'military_tech':
      return Icons.military_tech_rounded;
  }
  return Icons.workspace_premium_rounded;
}

Color _badgeColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return ZynkColors.primary;
  return Color(0xFF000000 | value);
}
