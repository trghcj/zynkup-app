// lib/features/user/screens/user_home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/login_choice_screen.dart';
import 'package:zynkup/features/user/screens/profile_setup_screen.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/user/screens/user_event_details_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  List<Event> _events = [];
  bool _loading = true;
  String? _userName;
  String? _avatarUrl;       // ← profile pic URL
  String _filter = "All";
  final _filters = ["All", "Upcoming", "Today", "Past"];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([_loadUser(), _fetchEvents()]);
  }

  Future<void> _loadUser() async {
    final u = await ApiService.getCurrentUser();
    if (u != null && mounted) {
      setState(() {
        _userName  = u["name"] ?? u["email"];
        _avatarUrl = u["avatar_url"] as String?;
      });
    }
  }

  Future<void> _fetchEvents() async {
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
    switch (_filter) {
      case "Upcoming":
        return _events.where((e) => e.date.isAfter(now)).toList();
      case "Today":
        return _events
            .where((e) =>
                e.date.isAfter(today) &&
                e.date.isBefore(today.add(const Duration(days: 1))))
            .toList();
      case "Past":
        return _events.where((e) => e.date.isBefore(now)).toList();
      default:
        return _events;
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginChoiceScreen()),
      (_) => false,
    );
  }

  // Reload user + events when coming back from profile screen
  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
    );
    // Refresh avatar after returning
    final u = await ApiService.getCurrentUser(force: true);
    if (u != null && mounted) {
      setState(() {
        _userName  = u["name"] ?? u["email"];
        _avatarUrl = u["avatar_url"] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final events = _filtered;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName != null
                              ? 'Hey, ${_userName!.split(' ').first} 👋'
                              : 'Hey there 👋',
                          style: TextStyle(
                            color: dark
                                ? ZynkColors.darkMuted
                                : ZynkColors.lightMuted,
                            fontSize: 13,
                          ),
                        ),
                        const Text(
                          'Discover Events',
                          style: TextStyle(
                            color: ZynkColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Profile avatar button ───────────────────
                  GestureDetector(
                    onTap: _openProfile,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ZynkColors.primary.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ZynkColors.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildAvatar(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── Logout button ───────────────────────────
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: dark
                            ? ZynkColors.darkSurface2
                            : ZynkColors.lightSurf2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: dark
                                ? ZynkColors.darkBorder
                                : ZynkColors.lightBorder),
                      ),
                      child: Icon(Icons.logout_rounded,
                          size: 18,
                          color: dark
                              ? ZynkColors.darkMuted
                              : ZynkColors.lightMuted),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Filter chips ──────────────────────────────────
            SizedBox(
              height: 36,
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
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: active ? ZynkGradients.brand : null,
                        color: active
                            ? null
                            : dark
                                ? ZynkColors.darkSurface2
                                : ZynkColors.lightSurf2,
                        borderRadius: BorderRadius.circular(20),
                        border: active
                            ? null
                            : Border.all(
                                color: dark
                                    ? ZynkColors.darkBorder
                                    : ZynkColors.lightBorder),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: ZynkColors.primary.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : dark
                                  ? ZynkColors.darkMuted
                                  : ZynkColors.lightMuted,
                          fontSize: 13,
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

            const SizedBox(height: 16),

            // ── Events list ───────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: ZynkColors.primary))
                  : RefreshIndicator(
                      color: ZynkColors.primary,
                      onRefresh: _fetchEvents,
                      child: events.isEmpty
                          ? _empty(dark)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: events.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) =>
                                  _EventCard(event: events[i]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows avatar image if available, otherwise gradient icon
  Widget _buildAvatar() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // base64 data URL (e.g. "data:image/jpeg;base64,/9j/...")
      if (_avatarUrl!.startsWith('data:')) {
        try {
          final base64Str = _avatarUrl!.split(',').last;
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarFallback(),
          );
        } catch (_) {
          return _avatarFallback();
        }
      }
      // Regular http/https URL
      return Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() => Container(
        decoration: const BoxDecoration(gradient: ZynkGradients.brand),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
      );

  Widget _empty(bool dark) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: ZynkColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event_busy_rounded,
              color: ZynkColors.primary, size: 36),
        ),
        const SizedBox(height: 16),
        Text('No events here',
            style: TextStyle(
                color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        const SizedBox(height: 4),
        Text('Check back soon!',
            style: TextStyle(
                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                fontSize: 13)),
      ]),
    );
  }
}

// ── Event Card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final Event event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isUpcoming = event.date.isAfter(DateTime.now());
    final cat = event.category.name;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          // ✅ Fixed: use UserEventDetailsScreen not EventDetailsScreen
          builder: (_) => UserEventDetailsScreen(event: event),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: ZynkColors.primary.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          children: [
            // ── Category colour strip ───────────────────────
            Container(
              width: 5,
              height: 90,
              decoration: BoxDecoration(
                gradient: ZynkGradients.forCategory(cat),
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),

            const SizedBox(width: 14),

            // ── Content ─────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CategoryBadge(cat),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isUpcoming
                                  ? ZynkColors.success
                                  : ZynkColors.lightMuted)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isUpcoming ? 'Upcoming' : 'Past',
                          style: TextStyle(
                            color: isUpcoming
                                ? ZynkColors.success
                                : ZynkColors.lightMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 7),
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            dark ? ZynkColors.darkText : ZynkColors.lightText,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.location_on_rounded,
                          size: 12,
                          color: dark
                              ? ZynkColors.darkMuted
                              : ZynkColors.lightMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          event.venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: dark
                                ? ZynkColors.darkMuted
                                : ZynkColors.lightMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded,
                          size: 12,
                          color: dark
                              ? ZynkColors.darkMuted
                              : ZynkColors.lightMuted),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('MMM dd').format(event.date),
                        style: TextStyle(
                          color: dark
                              ? ZynkColors.darkMuted
                              : ZynkColors.lightMuted,
                          fontSize: 12,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 14),

            Icon(Icons.chevron_right_rounded,
                color:
                    dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
                size: 20),

            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}