import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/features/clubs/screens/club_profile_screen.dart';
import 'package:zynkup/features/clubs/screens/create_club_screen.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  var _events = <Event>[];
  bool _loading = true;
  int _activeStudents = 0;
  int _eventsThisWeek = 0;
  List<String> _activeAvatars = [];
  List<dynamic> _clubs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ApiService.getEvents(force: true, limit: 50),
      ApiService.getCampusStats(),
      ApiService.getClubs(),
    ]);

    if (!mounted) return;

    final eventsData = results[0] as List<dynamic>;
    final statsData = results[1] as Map<String, dynamic>;
    final clubsData = results[2] as List<dynamic>;

    setState(() {
      _events = eventsData
          .map((item) => Event.fromJson(item as Map<String, dynamic>))
          .toList();
      _activeStudents = statsData['active_students'] as int? ?? 0;
      _eventsThisWeek = statsData['events_this_week'] as int? ?? 0;
      _activeAvatars = List<String>.from(statsData['active_avatars'] ?? []);
      _clubs = clubsData;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _events
        .where((event) => event.date.isAfter(DateTime.now()))
        .toList();
    final trending = [..._events]
      ..sort((a, b) => b.attendeeCount.compareTo(a.attendeeCount));

    return SafeArea(
      child: ZynkBackground(
        child: RefreshIndicator(
          color: ZynkColors.gold,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  activeStudents: _activeStudents,
                  eventsThisWeek: _eventsThisWeek,
                  activeAvatars: _activeAvatars,
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: ZynkColors.gold),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _ClubsSection(
                    clubs: _clubs,
                    onRefresh: _load,
                  ),
                ),
                _Section(
                  title: 'Featured Events',
                  events: _events.take(3).toList(),
                ),
                _Section(
                  title: 'Upcoming Events',
                  events: upcoming.take(5).toList(),
                ),
                _Section(title: 'Trending', events: trending.take(5).toList()),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int activeStudents;
  final int eventsThisWeek;
  final List<String> activeAvatars;

  const _Header({
    required this.activeStudents,
    required this.eventsThisWeek,
    required this.activeAvatars,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: ZynkColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ZYNKUP',
                style: TextStyle(
                  color: ZynkColors.gold,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'What is happening\naround you?',
            style: TextStyle(
              color: ZynkColors.darkText,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create, register, scan QR passes, and relive campus moments.',
            style: TextStyle(
              color: ZynkColors.darkMuted.withValues(alpha: 0.8),
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          // Live Activity Ticker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: ZynkGradients.cardSurface,
              borderRadius: BorderRadius.circular(ZynkRadius.lg),
              border: Border.all(color: ZynkColors.gold.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ZynkColors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, color: ZynkColors.orange, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$activeStudents+ students active now',
                        style: const TextStyle(
                          color: ZynkColors.offWhite,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '$eventsThisWeek events happening this week',
                        style: TextStyle(
                          color: ZynkColors.darkMuted.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Avatar Stack
                SizedBox(
                  width: 54,
                  height: 28,
                  child: Stack(
                    children: [
                      for (int i = 0; i < activeAvatars.length && i < 3; i++)
                        Positioned(
                          right: i * 14.0,
                          child: _AvatarBubble(activeAvatars[i]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final String url;
  const _AvatarBubble(this.url);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ZynkColors.darkSurface, width: 2),
        color: ZynkColors.darkSurface2,
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16, color: ZynkColors.darkMuted),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.events});

  final String title;
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Text(
            'Be the first to host something.',
            style: TextStyle(
              color: ZynkColors.darkMuted.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [ZynkColors.gold, ZynkColors.orange],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: ZynkColors.darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(
                width: 270,
                child: EventCardWidget(
                  event: events[index],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailsScreen(event: events[index]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubsSection extends StatelessWidget {
  final List<dynamic> clubs;
  final VoidCallback onRefresh;
  const _ClubsSection({required this.clubs, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (clubs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.groups_rounded, color: ZynkColors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Campus Clubs',
                    style: TextStyle(
                      color: ZynkColors.offWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateClubScreen()),
                  );
                  if (result == true) {
                    onRefresh();
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18, color: ZynkColors.gold),
                label: const Text(
                  'Create',
                  style: TextStyle(
                    color: ZynkColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index] as Map<String, dynamic>;
              final String clubName = club['name'] ?? '';
              final String clubId = (club['id'] ?? '').toString();
              final String? logoUrl = club['logo_url'];
              final displayImage = (logoUrl != null && logoUrl.isNotEmpty)
                  ? logoUrl
                  : 'https://picsum.photos/seed/$clubId/200/200';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClubProfileScreen(
                        clubId: clubId,
                        clubName: clubName,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: ZynkGradients.cardSurface,
                    borderRadius: BorderRadius.circular(ZynkRadius.lg),
                    border: Border.all(color: ZynkColors.darkBorder),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: ZynkColors.darkSurface2,
                        backgroundImage: NetworkImage(displayImage),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          clubName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ZynkColors.offWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
