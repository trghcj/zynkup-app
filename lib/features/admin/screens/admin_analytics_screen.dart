// lib/features/admin/screens/admin_analytics_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _isLoading = true;
  int totalEvents = 0;
  int totalUsers  = 0;
  int approved    = 0;
  int pending     = 0;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    try {
      // Uses ApiService which automatically sends the Bearer token
      final data = await ApiService.getAnalytics();
      if (data != null && mounted) {
        setState(() {
          totalEvents = data["total_events"]    ?? 0;
          totalUsers  = data["total_users"]     ?? 0;
          approved    = data["approved_events"] ?? 0;
          pending     = data["pending_events"]  ?? 0;
          _isLoading  = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasData = (approved + pending) > 0;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZynkColors.primary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchAnalytics,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: ZynkColors.primary,
        onRefresh: _fetchAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Pie chart ──────────────────────────────────
              Text('Event Overview',
                  style: TextStyle(
                    color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),

              const SizedBox(height: 20),

              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
                  ),
                ),
                child: hasData
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 50,
                                sections: [
                                  PieChartSectionData(
                                    value: approved.toDouble(),
                                    title: '$approved',
                                    color: ZynkColors.success,
                                    radius: 55,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: pending.toDouble(),
                                    title: '$pending',
                                    color: ZynkColors.warning,
                                    radius: 55,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Legend(color: ZynkColors.success, label: 'Approved'),
                              const SizedBox(height: 12),
                              _Legend(color: ZynkColors.warning, label: 'Pending'),
                            ],
                          ),
                        ]),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bar_chart_rounded,
                                size: 48,
                                color: dark
                                    ? ZynkColors.darkMuted
                                    : ZynkColors.lightMuted),
                            const SizedBox(height: 8),
                            Text('No event data yet',
                                style: TextStyle(
                                    color: dark
                                        ? ZynkColors.darkMuted
                                        : ZynkColors.lightMuted)),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 28),

              // ── Stats grid ──────────────────────────────────
              Text('Summary',
                  style: TextStyle(
                    color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),

              const SizedBox(height: 14),

              Row(children: [
                Expanded(child: _StatCard(
                  label: 'Total Events',
                  value: totalEvents,
                  icon: Icons.event_rounded,
                  color: ZynkColors.catSeminar,
                  dark: dark,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  label: 'Total Users',
                  value: totalUsers,
                  icon: Icons.people_rounded,
                  color: ZynkColors.catTech,
                  dark: dark,
                )),
              ]),

              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: _StatCard(
                  label: 'Approved',
                  value: approved,
                  icon: Icons.check_circle_rounded,
                  color: ZynkColors.success,
                  dark: dark,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  label: 'Pending',
                  value: pending,
                  icon: Icons.pending_actions_rounded,
                  color: ZynkColors.warning,
                  dark: dark,
                )),
              ]),

              const SizedBox(height: 24),

              // ── Approval rate ───────────────────────────────
              if (totalEvents > 0) ...[
                Text('Approval Rate',
                    style: TextStyle(
                      color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: dark
                            ? ZynkColors.darkBorder
                            : ZynkColors.lightBorder),
                  ),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Approved / Total',
                            style: TextStyle(
                                color: dark
                                    ? ZynkColors.darkMuted
                                    : ZynkColors.lightMuted,
                                fontSize: 13)),
                        Text(
                          '${((approved / totalEvents) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: ZynkColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: approved / totalEvents,
                        backgroundColor: dark
                            ? ZynkColors.darkSurface2
                            : ZynkColors.lightSurf2,
                        valueColor: const AlwaysStoppedAnimation(
                            ZynkColors.success),
                        minHeight: 8,
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool dark;
  const _StatCard({required this.label, required this.value,
    required this.icon, required this.color, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value.toString(),
              style: TextStyle(
                color: color, fontSize: 24,
                fontWeight: FontWeight.w900,
              )),
          Text(label,
              style: TextStyle(
                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                fontSize: 12,
              )),
        ]),
      ]),
    );
  }
}