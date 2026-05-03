import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading  = true;
  int totalEvents  = 0;
  int totalUsers   = 0;
  int pendingEvents = 0;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fetchData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getAnalytics(),
        ApiService.getPendingEvents(),
      ]);

      final analytics = results[0] as Map<String, dynamic>?;
      final pending   = results[1] as List<dynamic>;

      if (mounted) {
        setState(() {
          totalEvents   = analytics?["total_events"] as int? ?? 0;
          totalUsers    = analytics?["total_users"]  as int? ?? 0;
          pendingEvents = pending.length;
          _isLoading    = false;
        });
        _animController.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: ZynkColors.primary))
          : RefreshIndicator(
              color: ZynkColors.primary,
              onRefresh: _fetchData,
              child: CustomScrollView(slivers: [

                // ── Hero App Bar ──────────────────────────────
                SliverAppBar(
                  expandedHeight: 160,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                          gradient: ZynkGradients.brand),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800,
                                  letterSpacing: 2.5,
                                  // FIX: withOpacity -> withValues
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Dashboard',
                                  style: TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: -1,
                                  )),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    title: const Text('Dashboard',
                        style: TextStyle(color: Colors.white)),
                    titlePadding:
                        const EdgeInsets.only(left: 20, bottom: 16),
                  ),
                  backgroundColor: ZynkColors.primaryDark,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                      onPressed: _fetchData,
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildStatCard(
                        index: 0, title: 'Total Events', count: totalEvents,
                        icon: Icons.event_rounded, color: ZynkColors.primary,
                        subtitle: 'All time',
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        index: 1, title: 'Registered Users', count: totalUsers,
                        icon: Icons.people_rounded, color: ZynkColors.catTech,
                        subtitle: 'Platform wide',
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        index: 2, title: 'Pending Approval', count: pendingEvents,
                        icon: Icons.pending_actions_rounded,
                        color: ZynkColors.warning, subtitle: 'Needs review',
                        highlight: pendingEvents > 0,
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _buildStatCard({
    required int index,
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String subtitle,
    bool highlight = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final delay    = index * 0.15;
        final progress = Curves.easeOut.transform(
          ((_animController.value - delay) / (1 - delay)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            // FIX: withOpacity -> withValues
            color: highlight
                ? ZynkColors.warning.withValues(alpha: 0.4)
                : (dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
            width: highlight ? 1.5 : 1,
          ),
          boxShadow: highlight
              ? [BoxShadow(
                  // FIX: withOpacity -> withValues
                  color: ZynkColors.warning.withValues(alpha: 0.12),
                  blurRadius: 20, offset: const Offset(0, 4),
                )]
              : null,
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              // FIX: withOpacity -> withValues
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
              )),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(
                fontSize: 11,
                // FIX: withOpacity -> withValues
                color: (dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)
                    .withValues(alpha: 0.6),
              )),
            ],
          )),
          Text(count.toString(),
              style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.w800,
                color: color, letterSpacing: -1.5,
              )),
        ]),
      ),
    );
  }
}