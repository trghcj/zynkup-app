import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  var _events = <Event>[];
  bool _loading = true;
  String _category = 'all';

  static const _categories = [
    'all',
    'tech',
    'cultural',
    'sports',
    'workshop',
    'seminar',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getEvents(force: true, limit: 100);
    if (!mounted) return;
    setState(() {
      _events = data
          .map((item) => Event.fromJson(item as Map<String, dynamic>))
          .toList();
      _loading = false;
    });
  }

  List<Event> get _filtered => _category == 'all'
      ? _events
      : _events.where((event) => event.category.name == _category).toList();

  @override
  Widget build(BuildContext context) {
    final events = _filtered;
    return SafeArea(
      child: RefreshIndicator(
        color: ZynkColors.gold,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Explore',
                      style: TextStyle(
                        color: ZynkColors.darkText,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find events that match your vibe',
                      style: TextStyle(
                        color: ZynkColors.darkMuted.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final item = _categories[index];
                          final selected = item == _category;
                          return GestureDetector(
                            onTap: () => setState(() => _category = item),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? ZynkColors.deepOlive
                                    : ZynkColors.darkSurface2,
                                borderRadius: BorderRadius.circular(ZynkRadius.pill),
                                border: Border.all(
                                  color: selected
                                      ? ZynkColors.gold.withValues(alpha: 0.5)
                                      : ZynkColors.darkBorder,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: ZynkColors.gold.withValues(alpha: 0.12),
                                          blurRadius: 12,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                item == 'all'
                                    ? 'All'
                                    : item[0].toUpperCase() + item.substring(1),
                                style: TextStyle(
                                  color: selected
                                      ? ZynkColors.gold
                                      : ZynkColors.darkMuted,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
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
            else if (events.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: ZynkColors.gold.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search_off_rounded,
                          color: ZynkColors.gold.withValues(alpha: 0.5),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _category == 'all'
                            ? 'Be the first to host something.'
                            // ignore: unnecessary_brace_in_string_interps
                            : 'No ${_category} events yet.',
                        style: const TextStyle(
                          color: ZynkColors.darkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => EventCardWidget(
                    event: events[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EventDetailsScreen(event: events[index]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
