import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getEvents(force: true, limit: 50);
    if (!mounted) return;
    setState(() {
      _events = data
          .map((item) => Event.fromJson(item as Map<String, dynamic>))
          .toList();
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
      child: RefreshIndicator(
        color: ZynkColors.gold,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _Header()),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: ZynkColors.gold),
                ),
              )
            else ...[
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

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
        ],
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
