import 'package:zynkup/features/clubs/screens/all_clubs_screen.dart';
import 'package:zynkup/features/events/screens/past_events_screen.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/core/widgets/login_prompt_sheet.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/features/clubs/screens/club_profile_screen.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynkup/core/widgets/zynk_skeleton.dart';
import 'package:zynkup/core/widgets/zynk_empty_state.dart';

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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      _events = eventsData.map((item) => Event.fromJson(item as Map<String, dynamic>)).toList();
      _activeStudents = statsData['active_students'] as int? ?? 0;
      _eventsThisWeek = statsData['events_this_week'] as int? ?? 0;
      _activeAvatars = List<String>.from(statsData['active_avatars'] ?? []);
      _clubs = clubsData;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return SafeArea(
      child: ZynkBackground(
        child: RefreshIndicator(
          color: ZynkColors.primary,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: ZynkColors.offWhite),
                        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search events, clubs, or topics...',
                          hintStyle: const TextStyle(color: ZynkColors.darkMuted),
                          prefixIcon: const Icon(Icons.search_rounded, color: ZynkColors.darkMuted),
                          suffixIcon: _searchQuery.isNotEmpty 
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, color: ZynkColors.darkMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: ZynkColors.darkSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: ZynkColors.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: ZynkColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: ZynkColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                _buildSearchResults(isDesktop)
              else
                _buildDiscoverContent(isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDesktop) {
    final matchedEvents = _events.where((e) => e.title.toLowerCase().contains(_searchQuery) || e.category.name.toLowerCase().contains(_searchQuery)).toList();
    final matchedClubs = _clubs.where((c) => (c['name'] ?? '').toString().toLowerCase().contains(_searchQuery)).toList();
    
    if (matchedEvents.isEmpty && matchedClubs.isEmpty) {
      return SliverToBoxAdapter(
        child: ZEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results found',
          subtitle: 'Try searching for something else.',
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (matchedClubs.isNotEmpty) ...[
                  const Text('Clubs', style: TextStyle(color: ZynkColors.offWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: matchedClubs.map((club) {
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: club['id'].toString(), clubName: club['name']?.toString() ?? 'Club'))),
                        child: Container(
                          width: isDesktop ? 300 : MediaQuery.of(context).size.width - 40,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: ZynkColors.darkSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: ZynkColors.darkBorder)),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 24, backgroundColor: ZynkColors.darkSurface2, backgroundImage: club['logo_url'] != null ? CachedNetworkImageProvider(club['logo_url']) : null, child: club['logo_url'] == null ? const Icon(Icons.groups_rounded, color: ZynkColors.darkMuted) : null),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(club['name'] ?? 'Club', style: const TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(club['category'] ?? 'Community', style: const TextStyle(color: ZynkColors.primary, fontSize: 12)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
                if (matchedEvents.isNotEmpty) ...[
                  const Text('Events', style: TextStyle(color: ZynkColors.offWhite, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                  isDesktop 
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400, mainAxisSpacing: 20, crossAxisSpacing: 20, mainAxisExtent: 140),
                        itemCount: matchedEvents.length,
                        itemBuilder: (context, index) => EventCardWidget(event: matchedEvents[index], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: matchedEvents[index])))),
                      )
                    : Column(children: matchedEvents.map((e) => Padding(padding: const EdgeInsets.only(bottom: 16), child: EventCardWidget(event: e, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: e)))))).toList()),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverContent(bool isDesktop) {
    if (_loading) {
      return SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: List.generate(4, (index) => const Padding(padding: EdgeInsets.only(bottom: 20), child: ZSkeleton(width: double.infinity, height: 140, borderRadius: 16))),
              ),
            ),
          ),
        ),
      );
    }
    
    final filteredEvents = _events.where((event) {
      if (_filter == 'All Events') return true;
      return event.category.name.toLowerCase() == _filter.toLowerCase();
    }).toList();

    final upcoming = filteredEvents.where((event) => event.date.isAfter(DateTime.now())).toList();
    final past = filteredEvents.where((event) => event.date.isBefore(DateTime.now())).toList();
    past.sort((a, b) => b.date.compareTo(a.date));
    final displayedPast = isDesktop ? past.take(3).toList() : past.take(2).toList();

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(activeStudents: _activeStudents, eventsThisWeek: _eventsThisWeek, activeAvatars: _activeAvatars),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: ZynkColors.darkSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: ZynkColors.darkBorder)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filter,
                          dropdownColor: ZynkColors.darkSurface,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ZynkColors.primary, size: 18),
                          style: const TextStyle(color: ZynkColors.offWhite, fontSize: 13, fontWeight: FontWeight.w600),
                          items: ['All Events', 'tech', 'cultural', 'sports', 'workshop', 'seminar'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) setState(() => _filter = newValue);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Upcoming / Trending Title
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Text(
                  'Upcoming Events',
                  style: TextStyle(
                    color: ZynkColors.darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (upcoming.isEmpty)
                ZEmptyState(
                  icon: Icons.event_busy_rounded, 
                  title: 'No upcoming events', 
                  subtitle: 'There are no events scheduled right now.', 
                  actionLabel: 'Host an Event', 
                  onAction: () {
                    if (!ApiService.hasToken) {
                      showLoginPrompt(context, message: 'Sign in to host events.');
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventScreen())).then((_) => _load());
                  }
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: isDesktop 
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400, mainAxisSpacing: 20, crossAxisSpacing: 20, mainAxisExtent: 140),
                        itemCount: upcoming.length,
                        itemBuilder: (context, index) => EventCardWidget(event: upcoming[index], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: upcoming[index])))),
                      )
                    : Column(children: upcoming.map((e) => Padding(padding: const EdgeInsets.only(bottom: 16), child: EventCardWidget(event: e, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: e)))))).toList()),
                ),
              
              if (past.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Previous Events',
                        style: TextStyle(
                          color: ZynkColors.darkText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (past.length > displayedPast.length)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PastEventsScreen(initialEvents: _events),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View All',
                                style: TextStyle(
                                  color: ZynkColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: ZynkColors.primary),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: isDesktop 
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400, mainAxisSpacing: 20, crossAxisSpacing: 20, mainAxisExtent: 190),
                        itemCount: displayedPast.length,
                        itemBuilder: (context, index) => EventCardWidget(event: displayedPast[index], compact: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: displayedPast[index])))),
                      )
                    : Column(children: displayedPast.map((e) => Padding(padding: const EdgeInsets.only(bottom: 16), child: EventCardWidget(event: e, compact: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: e)))))).toList()),
                ),
                if (past.length > displayedPast.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PastEventsScreen(initialEvents: _events),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded, size: 16, color: ZynkColors.primary),
                        label: Text(
                          'View All Past Events (${past.length}) →',
                          style: const TextStyle(
                            color: ZynkColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              
              const SizedBox(height: 32),
              _ClubsSection(clubs: _clubs, onRefresh: _load),
              const SizedBox(height: 32),
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

// ignore: unused_element
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
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllClubsScreen()),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Clubs',
                      style: TextStyle(
                        color: ZynkColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: ZynkColors.primary),
                  ],
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
                  'No clubs founded yet.',
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
