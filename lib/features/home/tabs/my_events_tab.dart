import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';

class MyEventsTab extends StatefulWidget {
  const MyEventsTab({super.key});

  @override
  State<MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<MyEventsTab> {
  var _created = <Event>[];
  var _registered = <Event>[];
  bool _loading = true;
  int _segment = 0;
  String _filter = 'All Events';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final createdRaw = await ApiService.getMyEvents();
    final registeredRaw = await ApiService.getMyRegistrations();
    if (!mounted) return;
    setState(() {
      _created = createdRaw
          .map((item) => Event.fromJson(item as Map<String, dynamic>))
          .toList();
      _registered = registeredRaw
          .map(
            (item) => Event.fromJson(
              (item as Map<String, dynamic>)['event'] as Map<String, dynamic>,
            ),
          )
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawEvents = _segment == 0 ? _created : _registered;
    final events = rawEvents.where((event) {
      if (_filter == 'All Events') return true;
      return event.category.name.toLowerCase() == _filter.toLowerCase();
    }).toList();
    
    return SafeArea(
      child: RefreshIndicator(
        color: ZynkColors.gold,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Events',
                          style: TextStyle(
                            color: ZynkColors.darkText,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text('Created')),
                            ButtonSegment(value: 1, label: Text('Joined')),
                          ],
                          selected: {_segment},
                          onSelectionChanged: (value) =>
                              setState(() => _segment = value.first),
                        ),
                        const SizedBox(height: 16),
                        Row(
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
                      ],
                    ),
                  ),
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
                          _segment == 0
                              ? Icons.create_rounded
                              : Icons.bookmark_border_rounded,
                          color: ZynkColors.gold.withValues(alpha: 0.5),
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _segment == 0
                            ? 'Be the first to host something.'
                            : 'Join an event and your QR pass appears here.',
                        textAlign: TextAlign.center,
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
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 600) {
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: events.map((event) {
                                return SizedBox(
                                  width: (constraints.maxWidth - 16) / 2,
                                  child: EventCardWidget(
                                    event: event,
                                    onTap: () async {
                                      await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => EventDetailsScreen(event: event),
                                      );
                                      await _load();
                                    },
                                  ),
                                );
                              }).toList(),
                            );
                          }
                          
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: events.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) => EventCardWidget(
                              event: events[index],
                              onTap: () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => EventDetailsScreen(event: events[index]),
                                );
                                await _load();
                              },
                            ),
                          );
                        },
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
