// lib/features/home/tabs/explore_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  List<Event> _events = [];
  bool _loading = true;
  String _filter = 'All';
  String _category = 'All';

  final _filters = ['All', 'Upcoming', 'Today', 'Past'];
  final _categories = [
    'All',
    'Tech',
    'Cultural',
    'Sports',
    'Workshop',
    'Seminar',
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getEvents(force: true);
      if (mounted) {
        setState(() {
          _events = data
              .map<Event>((e) => Event.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Event> get _filtered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var list = _events;

    // Category filter
    if (_category != 'All') {
      list = list
          .where(
            (e) => e.category.name.toLowerCase() == _category.toLowerCase(),
          )
          .toList();
    }

    // Time filter
    switch (_filter) {
      case 'Upcoming':
        return list.where((e) => e.date.isAfter(now)).toList();
      case 'Today':
        return list
            .where(
              (e) =>
                  e.date.isAfter(today) &&
                  e.date.isBefore(today.add(const Duration(days: 1))),
            )
            .toList();
      case 'Past':
        return list.where((e) => e.date.isBefore(now)).toList();
      default:
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _filtered;

    return RefreshIndicator(
      color: ZynkColors.primary,
      onRefresh: _fetch,
      child: CustomScrollView(
        slivers: [
          // ── Search bar + greeting ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => ZynkGradients.brand.createShader(b),
                    child: const Text(
                      'Explore Events',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_events.length} events happening around you',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Category chips ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final active = _category == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? ZynkColors.forCategory(
                                  cat.toLowerCase(),
                                ).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? ZynkColors.forCategory(
                                    cat.toLowerCase(),
                                  ).withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: active
                                ? ZynkColors.forCategory(cat.toLowerCase())
                                : Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Time filter chips ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 16),
              child: SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _filters[i];
                    final active = _filter == f;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: active ? ZynkGradients.brand : null,
                          color: active
                              ? null
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: active
                              ? null
                              : Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: ZynkColors.primary),
              ),
            )
          else if (events.isEmpty)
            SliverFillRemaining(child: _empty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EventCard(event: events[i]),
                  ),
                  childCount: events.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: ZynkColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.search_off_rounded,
            color: ZynkColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'No events found',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Try a different filter',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

// ── Event Card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final Event event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = event.date.isAfter(DateTime.now());
    final cat = event.category.name;
    final hasImage = event.imageUrls.isNotEmpty;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EventDetailsScreen(event: event),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: CachedNetworkImage(imageUrl: event.imageUrls.first,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _strip(cat),
                ),
              )
            else
              _strip(cat),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CategoryBadge(cat),
                      const Spacer(),
                      _statusChip(isUpcoming),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          event.venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('MMM dd · hh:mm a').format(event.date),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 13,
                        color: ZynkColors.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${event.registeredUsers.length} student${event.registeredUsers.length == 1 ? '' : 's'} joined 🚀',
                        style: TextStyle(
                          color: ZynkColors.primary.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strip(String cat) => Container(
    height: 5,
    decoration: BoxDecoration(
      gradient: ZynkGradients.forCategory(cat),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    ),
  );

  Widget _statusChip(bool upcoming) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (upcoming ? ZynkColors.success : Colors.white30).withValues(
        alpha: 0.15,
      ),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      upcoming ? 'Upcoming' : 'Past',
      style: TextStyle(
        color: upcoming ? ZynkColors.success : Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
