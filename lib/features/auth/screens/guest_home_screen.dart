import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/features/auth/screens/login_screen.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  var _events = <Event>[];
  bool _loading = true;
  String _category = 'all';

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

  List<Event> get _filtered {
    if (_category == 'all') return _events;
    return _events.where((event) => event.category.name == _category).toList();
  }

  void _login() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _filtered;
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Hero(onLogin: _login)),
              SliverToBoxAdapter(
                child: _Categories(
                  value: _category,
                  onChanged: (v) => setState(() => _category = v),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (events.isEmpty)
                const SliverFillRemaining(child: _EmptyGuest())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                  sliver: SliverList.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, index) => EventCardWidget(
                      event: events[index],
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => EventDetailsScreen(
                          event: events[index],
                          isGuest: true,
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

class _Hero extends StatelessWidget {
  const _Hero({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: ZynkColors.primary,
                size: 30,
              ),
              const SizedBox(width: 8),
              const Text(
                'ZYNKUP',
                style: TextStyle(
                  color: ZynkColors.darkText,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: onLogin, child: const Text('Login')),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Find what is happening on campus.',
            style: TextStyle(
              color: ZynkColors.darkText,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Browse featured, nearby, latest, and category events. Login to participate.',
            style: TextStyle(color: ZynkColors.darkMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const categories = [
    'all',
    'tech',
    'cultural',
    'sports',
    'workshop',
    'seminar',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = categories[index];
          final active = item == value;
          return ChoiceChip(
            selected: active,
            label: Text(
              item == 'all' ? 'All' : item[0].toUpperCase() + item.substring(1),
            ),
            onSelected: (_) => onChanged(item),
          );
        },
      ),
    );
  }
}

class _EmptyGuest extends StatelessWidget {
  const _EmptyGuest();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Your next campus moment starts here.',
        style: TextStyle(color: ZynkColors.darkMuted),
      ),
    );
  }
}
