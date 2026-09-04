import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/core/widgets/login_prompt_sheet.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/features/clubs/screens/club_profile_screen.dart';
import 'package:zynkup/features/clubs/screens/create_club_screen.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  String _filter = 'All Events';

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
    final filteredEvents = _events.where((event) {
      if (_filter == 'All Events') return true;
      return event.category.name.toLowerCase() == _filter.toLowerCase();
    }).toList();

    final upcoming = filteredEvents
        .where((event) => event.date.isAfter(DateTime.now()))
        .toList();
    final trending = [...filteredEvents]
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: ZynkColors.darkSurface,
                          borderRadius: BorderRadius.circular(ZynkRadius.md),
                          border: Border.all(color: ZynkColors.darkBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filter,
                            dropdownColor: ZynkColors.darkSurface,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ZynkColors.primary, size: 18),
                            style: const TextStyle(color: ZynkColors.darkText, fontSize: 13, fontWeight: FontWeight.w600),
                            items: ['All Events', 'Tech', 'Cultural', 'Sports', 'Workshop', 'Seminar'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _filter = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: ZynkColors.gold),
                  ),
                )
              else ...[
                _Section(
                  title: 'Featured Events',
                  events: filteredEvents.take(3).toList(),
                ),
                _Section(
                  title: 'Upcoming Events',
                  events: upcoming.take(5).toList(),
                ),
                _Section(title: 'Trending', events: trending.take(5).toList()),
                SliverToBoxAdapter(
                  child: _ClubsSection(
                    clubs: _clubs,
                    onRefresh: _load,
                  ),
                ),
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
          const Text(
            'What is happening\naround you?',
            style: TextStyle(
              color: ZynkColors.darkText,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create, register, scan QR passes, and relive campus moments.',
            style: TextStyle(
              color: ZynkColors.darkMuted,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          // Live Activity Ticker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ZynkColors.darkSurface,
              borderRadius: BorderRadius.circular(ZynkRadius.lg),
              border: Border.all(color: ZynkColors.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ZynkColors.warmAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, color: ZynkColors.warmAccent, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$activeStudents+ students active now',
                        style: const TextStyle(
                          color: ZynkColors.darkText,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '$eventsThisWeek events happening this week',
                        style: const TextStyle(
                          color: ZynkColors.darkMuted,
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
        child: CachedNetworkImage(imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const Icon(Icons.person, size: 16, color: ZynkColors.darkMuted),
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
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Text(
                'No events found.',
                style: TextStyle(
                  color: ZynkColors.darkMuted.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                
                if (isDesktop) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: events.map((event) {
                        return SizedBox(
                          width: 320,
                          child: EventCardWidget(
                            event: event,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => EventDetailsScreen(event: event),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }

                return SizedBox(
                  height: 310,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) => TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 350 + (index * 80)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 16 * (1.0 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 270,
                        child: EventCardWidget(
                          event: events[index],
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => EventDetailsScreen(event: events[index]),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
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
                  Icon(Icons.groups_rounded, color: ZynkColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Campus Clubs',
                    style: TextStyle(
                      color: ZynkColors.darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () async {
                  if (!ApiService.hasToken) {
                    showLoginPrompt(context, message: 'Sign in to found a campus club.');
                    return;
                  }
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateClubScreen()),
                  );
                  if (result == true) {
                    onRefresh();
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18, color: ZynkColors.primary),
                label: const Text(
                  'Create',
                  style: TextStyle(
                    color: ZynkColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (clubs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: ZynkColors.darkSurface,
                borderRadius: BorderRadius.circular(ZynkRadius.lg),
                border: Border.all(color: ZynkColors.darkBorder),
              ),
              child: const Center(
                child: Text(
                  'No clubs founded yet. Tap Create to start one!',
                  style: TextStyle(color: ZynkColors.darkMuted, fontSize: 13),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 160,
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

                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + (index * 60)),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(16 * (1.0 - value), 0),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ClubProfileScreen(
                          clubId: clubId,
                          clubName: clubName,
                          clubData: club,
                        ),
                      );
                    },
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ZynkColors.darkSurface,
                        borderRadius: BorderRadius.circular(ZynkRadius.lg),
                        border: Border.all(color: ZynkColors.darkBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(ZynkRadius.sm),
                            child: CachedNetworkImage(
                              imageUrl: displayImage,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            clubName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ZynkColors.darkText,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Campus Club',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ZynkColors.darkMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
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
