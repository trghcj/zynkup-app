// lib/features/admin/screens/admin_home_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/login_choice_screen.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
import 'package:zynkup/features/widgets/event_list_widget.dart';
import 'package:zynkup/features/admin/screens/admin_event_approval_screen.dart';
import 'package:zynkup/features/admin/screens/admin_analytics_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int users = 0, totalEvents = 0, approved = 0, pending = 0;
  bool _loading = true;
  String? _adminName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getAnalytics(),
        ApiService.getPendingEvents(),
        ApiService.getCurrentUser(),
      ]);
      final analytics = results[0] as Map<String, dynamic>?;
      final pendingList = results[1] as List<dynamic>;
      final user = results[2] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          users       = analytics?["total_users"] ?? 0;
          totalEvents = analytics?["total_events"] ?? 0;
          approved    = analytics?["approved_events"] ?? 0;
          pending     = pendingList.length;
          _adminName  = user?["name"] ?? user?["email"] ?? "Admin";
          _loading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginChoiceScreen()),
        (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                gradient: ZynkGradients.brand,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: ZynkColors.primary),
          ]),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: ZynkColors.primary,
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────
                _Header(adminName: _adminName ?? "Admin", onLogout: _logout,
                  onAnalytics: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()))
                      .then((_) => _load()),
                  onRefresh: _load,
                ),

                // ── Stats grid ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overview',
                          style: TextStyle(
                            color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          )),

                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(child: _StatCard(label: 'Users', value: users,
                            icon: Icons.people_rounded, color: ZynkColors.catTech)),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(label: 'Events', value: totalEvents,
                            icon: Icons.event_rounded, color: ZynkColors.catSeminar)),
                      ]),

                      const SizedBox(height: 12),

                      Row(children: [
                        Expanded(child: _StatCard(label: 'Approved', value: approved,
                            icon: Icons.check_circle_rounded, color: ZynkColors.success)),
                        const SizedBox(width: 12),
                        Expanded(child: GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AdminEventApprovalScreen()))
                              .then((_) => _load()),
                          child: _StatCard(label: 'Pending', value: pending,
                              icon: Icons.pending_actions_rounded,
                              color: ZynkColors.warning,
                              highlight: pending > 0),
                        )),
                      ]),

                      // ── Pending banner ───────────────────────
                      if (pending > 0) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AdminEventApprovalScreen()))
                              .then((_) => _load()),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5A3E00), Color(0xFF8A6000)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.warning_amber_rounded,
                                    color: ZynkColors.accentLight, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$pending event${pending > 1 ? "s" : ""} awaiting approval',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      )),
                                  const Text('Tap to review',
                                      style: TextStyle(
                                          color: ZynkColors.accentLight,
                                          fontSize: 12)),
                                ],
                              )),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white),
                            ]),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Quick actions ────────────────────────
                      Text('Quick Actions',
                          style: TextStyle(
                            color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          )),

                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(child: _QuickAction(
                          label: 'Create Event',
                          icon: Icons.add_circle_rounded,
                          gradient: ZynkGradients.brand,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const CreateEventScreen()))
                              .then((_) => _load()),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _QuickAction(
                          label: 'Approvals',
                          icon: Icons.fact_check_rounded,
                          gradient: const LinearGradient(
                              colors: [Color(0xFF5A3E00), ZynkColors.catCultural]),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AdminEventApprovalScreen()))
                              .then((_) => _load()),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _QuickAction(
                          label: 'Analytics',
                          icon: Icons.bar_chart_rounded,
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A5F), ZynkColors.catTech]),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()))
                              .then((_) => _load()),
                        )),
                      ]),

                      const SizedBox(height: 24),

                      Text('All Events',
                          style: TextStyle(
                            color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          )),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                const SizedBox(height: 500, child: EventListWidget()),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String adminName;
  final VoidCallback onLogout, onAnalytics, onRefresh;
  const _Header({required this.adminName, required this.onLogout,
    required this.onAnalytics, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(gradient: ZynkGradients.brand),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ZYNKUP ADMIN',
                  style: TextStyle(
                    color: Colors.white60, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5,
                  )),
              Text('Hey, ${adminName.split(' ').first} 👋',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 24,
                    fontWeight: FontWeight.w900, letterSpacing: -0.5,
                  )),
            ],
          )),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
          IconButton(
            onPressed: onAnalytics,
            icon: const Icon(Icons.analytics_rounded, color: Colors.white70),
          ),
          GestureDetector(
            onTap: onLogout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(children: [
                Icon(Icons.logout_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Logout', style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool highlight;
  const _StatCard({required this.label, required this.value,
    required this.icon, required this.color, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? color.withOpacity(0.4) :
              (dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 12),
        Text(value.toString(),
            style: TextStyle(
              color: color, fontSize: 26,
              fontWeight: FontWeight.w900, letterSpacing: -0.5,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
              color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
              fontSize: 12, fontWeight: FontWeight.w500,
            )),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  const _QuickAction({required this.label, required this.icon,
    required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}