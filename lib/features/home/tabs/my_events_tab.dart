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
    final events = _segment == 0 ? _created : _registered;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
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
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Created')),
                        ButtonSegment(value: 1, label: Text('Joined')),
                      ],
                      selected: {_segment},
                      onSelectionChanged: (value) =>
                          setState(() => _segment = value.first),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (events.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _segment == 0
                        ? 'Be the first to host something.'
                        : 'Join an event and your QR pass appears here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ZynkColors.darkMuted),
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
