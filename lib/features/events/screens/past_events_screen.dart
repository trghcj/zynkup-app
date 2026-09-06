import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/core/widgets/zynk_skeleton.dart';
import 'package:zynkup/core/widgets/zynk_empty_state.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';

class PastEventsScreen extends StatefulWidget {
  final List<Event>? initialEvents;

  const PastEventsScreen({super.key, this.initialEvents});

  @override
  State<PastEventsScreen> createState() => _PastEventsScreenState();
}

class _PastEventsScreenState extends State<PastEventsScreen> {
  bool _loading = false;
  List<Event> _events = [];
  String _searchQuery = '';
  String _filter = 'All Events';
  final TextEditingController _searchController = TextEditingController();

  static const _categories = [
    'All Events',
    'tech',
    'cultural',
    'sports',
    'workshop',
    'seminar',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialEvents != null && widget.initialEvents!.isNotEmpty) {
      _events = List.from(widget.initialEvents!);
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.getEvents(force: true, limit: 100);
    if (!mounted) {
      return;
    }
    setState(() {
      _events = data
          .map((item) => Event.fromJson(item as Map<String, dynamic>))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Filter only events that took place in the past
    final pastEvents = _events.where((event) => event.date.isBefore(now)).toList();
    // Sort descending: most recent past events first
    pastEvents.sort((a, b) => b.date.compareTo(a.date));

    final filtered = pastEvents.where((event) {
      final matchesCategory = _filter == 'All Events' ||
          event.category.name.toLowerCase() == _filter.toLowerCase();
      if (!matchesCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) {
        return true;
      }
      final title = event.title.toLowerCase();
      final venue = event.venue.toLowerCase();
      final desc = event.description.toLowerCase();
      return title.contains(_searchQuery) ||
          venue.contains(_searchQuery) ||
          desc.contains(_searchQuery);
    }).toList();

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(
        title: const Text(
          'Previous Events',
          style: TextStyle(
            color: ZynkColors.offWhite,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ZynkBackground(
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search field
                          TextField(
                            controller: _searchController,
                            style: const TextStyle(color: ZynkColors.offWhite),
                            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                            decoration: InputDecoration(
                              hintText: 'Search past events by title, venue...',
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
                          const SizedBox(height: 16),
                          // Dropdown and count row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${filtered.length} Past ${filtered.length == 1 ? "Event" : "Events"}',
                                style: const TextStyle(
                                  color: ZynkColors.darkMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ZynkColors.darkSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: ZynkColors.darkBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _filter,
                                    dropdownColor: ZynkColors.darkSurface,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: ZynkColors.primary,
                                      size: 18,
                                    ),
                                    style: const TextStyle(
                                      color: ZynkColors.offWhite,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    items: _categories.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      if (newValue != null) {
                                        setState(() => _filter = newValue);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_loading)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: List.generate(
                            3,
                            (index) => const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: ZSkeleton(
                                width: double.infinity,
                                height: 140,
                                borderRadius: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: ZEmptyState(
                    icon: Icons.history_rounded,
                    title: _searchQuery.isEmpty && _filter == 'All Events'
                        ? 'No past events'
                        : 'No events match your search',
                    subtitle: _searchQuery.isEmpty && _filter == 'All Events'
                        ? 'Completed campus events will be archived here.'
                        : 'Try adjusting your search or category filter.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: isDesktop
                            ? GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 400,
                                  mainAxisSpacing: 20,
                                  crossAxisSpacing: 20,
                                  mainAxisExtent: 190,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) => EventCardWidget(
                                  event: filtered[index],
                                  compact: true,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EventDetailsScreen(event: filtered[index]),
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: filtered.map((e) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: EventCardWidget(
                                      event: e,
                                      compact: true,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EventDetailsScreen(event: e),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
