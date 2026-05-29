// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/theme/theme_provider.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:zynkup/features/profile/widgets/dice_bear_avatar.dart';
import 'package:zynkup/features/profile/widgets/activity_heatmap.dart';
import 'package:zynkup/features/profile/screens/avatar_gallery_screen.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  Map<String, int> _heatmapData = {};
  List<Event> _createdEvents = [];
  List<Event> _joinedEvents = [];
  List<dynamic> _timeline = [];
  bool _loading = true;

  late TabController _tabController;

  final _nameC = TextEditingController();
  final _bioC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    // Each call is independent — one failure shouldn't kill the others
    final results = await Future.wait([
      ApiService.getCurrentUser(force: true).catchError((_) => null),
      ApiService.getHeatmapData().catchError((_) => <String, int>{}),
      ApiService.getMyEvents().catchError((_) => <dynamic>[]),
      ApiService.getMyRegistrations().catchError((_) => <dynamic>[]),
      ApiService.getTimeline().catchError((_) => <dynamic>[]),
    ]);
    if (!mounted) return;
    final user = results[0] as Map<String, dynamic>?;
    final heatmap = (results[1] is Map<String, int>)
        ? results[1] as Map<String, int>
        : <String, int>{};
    final createdRaw = (results[2] is List) ? results[2] as List<dynamic> : <dynamic>[];
    final joinedRaw = (results[3] is List) ? results[3] as List<dynamic> : <dynamic>[];
    final timelineRaw = (results.length > 4 && results[4] is List) ? results[4] as List<dynamic> : <dynamic>[];

    setState(() {
      _user = user;
      _heatmapData = heatmap;
      _createdEvents = createdRaw
          .whereType<Map<String, dynamic>>()
          .map(Event.fromJson)
          .toList();
      _joinedEvents = joinedRaw
          .whereType<Map<String, dynamic>>()
          .map((item) => item['event'])
          .whereType<Map<String, dynamic>>()
          .map(Event.fromJson)
          .toList();
      _timeline = timelineRaw;
      _loading = false;
      if (user != null) {
        _nameC.text = user['name'] ?? '';
        _bioC.text = user['bio'] ?? '';
      }
    });
  }

  Future<void> _randomizeAvatar() async {
    final newSeed = DateTime.now().millisecondsSinceEpoch.toString();
    await ApiService.updateProfile(avatarSeed: newSeed);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ZynkColors.gold));
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
      body: ZynkBackground(
        child: CustomScrollView(
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
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white10,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    ZynkColors.gold,
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
                                    gradient: const LinearGradient(
                                      colors: [ZynkColors.gold, ZynkColors.orange],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(color: ZynkColors.gold.withValues(alpha: 0.3), blurRadius: 8),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(ZynkColors.gold),
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
                          style: TextStyle(color: ZynkColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
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
              indicatorColor: ZynkColors.gold,
              indicatorWeight: 3,
              labelColor: ZynkColors.offWhite,
              unselectedLabelColor: ZynkColors.darkMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              dividerColor: Colors.transparent,
              onTap: (index) => setState(() {}),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Timeline'),
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
                _TimelineTab(timeline: _timeline),
                _EventsTab(
                  createdEvents: _createdEvents,
                  joinedEvents: _joinedEvents,
                  onRefresh: _load,
                ),
                _BadgesTab(user: user),
              ][_tabController.index],
            ),
          ),
        ],
        ),
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
        gradient: ZynkGradients.cardSurface,
        borderRadius: BorderRadius.circular(ZynkRadius.lg),
        border: Border.all(color: ZynkColors.darkBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ZynkColors.gold.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: ZynkColors.gold, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: ZynkColors.offWhite,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: ZynkColors.darkMuted.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
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
          const _ThemeToggleTile(),
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

class _ThemeToggleTile extends StatelessWidget {
  const _ThemeToggleTile();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeProvider,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZynkColors.darkSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZynkColors.darkBorder),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZynkColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.palette_rounded, color: ZynkColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Theme Mode',
                    style: TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SegmentedButton<AppThemeMode>(
                segments: const [
                  ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
                  ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: AppThemeMode.system, label: Text('System')),
                ],
                selected: {themeProvider.currentTheme},
                onSelectionChanged: (selection) => themeProvider.setTheme(selection.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? ZynkColors.darkBg
                        : ZynkColors.darkMuted,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? ZynkColors.gold
                        : ZynkColors.darkSurface,
                  ),
                  side: WidgetStateProperty.all(
                    BorderSide(color: ZynkColors.darkBorder.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineTab extends StatelessWidget {
  final List<dynamic> timeline;
  const _TimelineTab({required this.timeline});

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        title: 'No Activity Yet',
        message: 'Join clubs, register for events, or post to your feed to see your activity here.',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: timeline.length,
        itemBuilder: (context, index) {
          final item = timeline[index];
          final type = item['type'] as String? ?? '';
          final title = item['title'] as String? ?? '';
          final dateStr = item['date'] as String?;

          IconData icon;
          Color color;
          if (type == 'event_registration') {
            icon = Icons.event_available_rounded;
            color = ZynkColors.accent;
          } else if (type == 'club_join') {
            icon = Icons.groups_rounded;
            color = ZynkColors.primary;
          } else {
            icon = Icons.post_add_rounded;
            color = ZynkColors.gold;
          }

          String timeAgo = 'recently';
          if (dateStr != null) {
            try {
              final dt = DateTime.parse(dateStr).toLocal();
              final diff = DateTime.now().difference(dt);
              if (diff.inDays > 0) {
                timeAgo = '${diff.inDays}d ago';
              } else if (diff.inHours > 0) {
                timeAgo = '${diff.inHours}h ago';
              } else if (diff.inMinutes > 0) {
                timeAgo = '${diff.inMinutes}m ago';
              } else {
                timeAgo = 'just now';
              }
            } catch (_) {}
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ZynkColors.darkSurface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZynkColors.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(timeAgo, style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
  const _EventsTab({
    required this.createdEvents,
    required this.joinedEvents,
    required this.onRefresh,
  });

  final List<Event> createdEvents;
  final List<Event> joinedEvents;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final allEvents = [
      ...createdEvents.map((event) => (event: event, label: 'Created')),
      ...joinedEvents.map((event) => (event: event, label: 'Joined')),
    ];
    if (allEvents.isEmpty) {
      return const _EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No events yet',
        message: 'Events you create or join will appear here.',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 920
              ? 3
              : constraints.maxWidth >= 620
                  ? 2
                  : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allEvents.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: columns == 1 ? 1.35 : 0.92,
            ),
            itemBuilder: (context, index) {
              final item = allEvents[index];
              return Stack(
                children: [
                  Positioned.fill(
                    child: EventCardWidget(
                      event: item.event,
                      onTap: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => EventDetailsScreen(event: item.event),
                        );
                        await onRefresh();
                      },
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: ZynkColors.deepOlive.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: ZynkColors.sand.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: ZynkColors.offWhite,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
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

class _BadgeTile extends StatefulWidget {
  const _BadgeTile({required this.badge});
  final _ProfileBadge badge;

  @override
  State<_BadgeTile> createState() => _BadgeTileState();
}

class _BadgeTileState extends State<_BadgeTile> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final color = badge.unlocked ? badge.color : ZynkColors.darkMuted;

    return GestureDetector(
      onTapDown: (_) => _anim.reverse(),
      onTapUp: (_) => _anim.forward(),
      onTapCancel: () => _anim.forward(),
      child: ScaleTransition(
        scale: _anim,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: ZynkGradients.cardSurface,
            borderRadius: BorderRadius.circular(ZynkRadius.lg),
            border: Border.all(
              color: badge.unlocked
                  ? color.withValues(alpha: 0.4)
                  : ZynkColors.darkBorder.withValues(alpha: 0.4),
            ),
            boxShadow: badge.unlocked
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ]
                : null,
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
                      : ZynkColors.darkMuted.withValues(alpha: 0.5),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: ZynkGradients.cardSurface,
              borderRadius: BorderRadius.circular(ZynkRadius.xl),
              border: Border.all(color: ZynkColors.darkBorder.withValues(alpha: 0.5)),
              boxShadow: ZynkShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: ZynkColors.gold.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: ZynkColors.gold.withValues(alpha: 0.7), size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ZynkColors.darkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ZynkColors.darkMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
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
  if (raw is List && raw.isNotEmpty) {
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
  // Compute unlock states from the user stats we already have
  final eventsCreated = user['events_created'] ?? 0;
  final attended = user['attended'] ?? 0;
  final totalRegistered = user['total_registered'] ?? 0;
  final level = user['level'] ?? 1;
  final streak = user['streak'] ?? 0;
  final role = (user['role'] ?? 'user').toString();
  final id = user['id'] ?? 999;
  final totalAttendees = user['total_attendees'] ?? 0;
  return [
    _ProfileBadge(
      name: 'First Event',
      description: 'Register for your first event.',
      icon: Icons.event_available_rounded,
      color: const Color(0xFFF97316),
      unlocked: (totalRegistered as int) >= 1,
    ),
    _ProfileBadge(
      name: 'Explorer',
      description: 'Register for 3 events.',
      icon: Icons.explore_rounded,
      color: const Color(0xFF38BDF8),
      unlocked: totalRegistered >= 3,
    ),
    _ProfileBadge(
      name: 'First Creator',
      description: 'Create your first event.',
      icon: Icons.add_circle_rounded,
      color: const Color(0xFFA78BFA),
      unlocked: (eventsCreated as int) >= 1,
    ),
    _ProfileBadge(
      name: 'Rising Star',
      description: 'Reach level 3.',
      icon: Icons.star_rounded,
      color: const Color(0xFFFACC15),
      unlocked: (level as int) >= 3,
    ),
    _ProfileBadge(
      name: 'Community Hero',
      description: 'Attend 5 events.',
      icon: Icons.volunteer_activism_rounded,
      color: const Color(0xFF22C55E),
      unlocked: (attended as int) >= 5,
    ),
    _ProfileBadge(
      name: '7-Day Streak',
      description: 'Keep a 7-day activity streak.',
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFEF4444),
      unlocked: (streak as int) >= 7,
    ),
    _ProfileBadge(
      name: 'Verified Organizer',
      description: 'Become an organizer or admin.',
      icon: Icons.verified_rounded,
      color: const Color(0xFF14B8A6),
      unlocked: role == 'organizer' || role == 'admin',
    ),
    _ProfileBadge(
      name: 'Founding Member',
      description: 'Be among the first 100 Zynkup members.',
      icon: Icons.workspace_premium_rounded,
      color: const Color(0xFFFB7185),
      unlocked: (id as int) <= 100,
    ),
    _ProfileBadge(
      name: 'Crowd Magnet',
      description: 'Bring 10 total attendees to your events.',
      icon: Icons.groups_rounded,
      color: const Color(0xFF60A5FA),
      unlocked: (totalAttendees as int) >= 10,
    ),
    _ProfileBadge(
      name: 'Elite Member',
      description: 'Reach level 10.',
      icon: Icons.military_tech_rounded,
      color: const Color(0xFFF59E0B),
      unlocked: level >= 10,
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
