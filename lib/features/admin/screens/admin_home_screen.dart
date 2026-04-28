// lib/features/admin/screens/admin_home_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/login_choice_screen.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
import 'package:zynkup/features/admin/screens/admin_event_approval_screen.dart';
import 'package:zynkup/features/admin/screens/admin_analytics_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  int  _selectedIndex   = 0;
  bool _sidebarExpanded = true;
  String _adminName   = 'Admin';
  int _pendingCount   = 0;
  int _totalEvents    = 0;
  int _totalUsers     = 0;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final user      = await ApiService.getCurrentUser();
    final analytics = await ApiService.getAnalytics();
    final pending   = await ApiService.getPendingEvents();
    if (mounted) {
      setState(() {
        _adminName    = user?['name'] ?? user?['email'] ?? 'Admin';
        _totalEvents  = analytics?['total_events']  ?? 0;
        _totalUsers   = analytics?['total_users']   ?? 0;
        _pendingCount = pending.length;
      });
      _animController.forward();
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginChoiceScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            expanded:      _sidebarExpanded,
            selectedIndex: _selectedIndex,
            adminName:     _adminName,
            pendingCount:  _pendingCount,
            onToggle:  () => setState(() => _sidebarExpanded = !_sidebarExpanded),
            onSelect:  (i) => setState(() => _selectedIndex = i),
            onLogout:  _logout,
            dark:      dark,
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _DashboardContent(
                    adminName:    _adminName,
                    totalEvents:  _totalEvents,
                    totalUsers:   _totalUsers,
                    pendingCount: _pendingCount,
                    onCreateEvent: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CreateEventScreen()))
                        .then((_) => _loadData()),
                    onApprovals: () => setState(() => _selectedIndex = 1),
                    onAnalytics: () => setState(() => _selectedIndex = 2),
                    dark: dark,
                  ),
                  const AdminEventApprovalScreen(),
                  const AdminAnalyticsScreen(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final bool expanded;
  final int  selectedIndex;
  final String adminName;
  final int  pendingCount;
  final VoidCallback        onToggle;
  final ValueChanged<int>   onSelect;
  final VoidCallback        onLogout;
  final bool dark;

  // collapsed width must be wide enough for icon (20) + padding (8*2) + border
  static const double kCollapsed = 52;
  static const double kExpanded  = 210;

  const _Sidebar({
    required this.expanded, required this.selectedIndex,
    required this.adminName, required this.pendingCount,
    required this.onToggle, required this.onSelect,
    required this.onLogout, required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final w = expanded ? kExpanded : kCollapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: w,
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        border: Border(right: BorderSide(
            color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder)),
      ),
      // ── clip so nothing escapes during animation ──
      child: ClipRect(
        child: OverflowBox(
          minWidth: 0, maxWidth: kExpanded,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: kExpanded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),

                // ── Logo row ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    // Logo — always visible
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: ZynkGradients.brand,
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 18)),
                    const SizedBox(width: 8),
                    // Label fades with animation
                    Expanded(child: AnimatedOpacity(
                      opacity: expanded ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text('ZYNKUP',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: dark ? ZynkColors.darkText : ZynkColors.lightText),
                          overflow: TextOverflow.clip),
                    )),
                    // Toggle — always visible
                    GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder)),
                        child: Icon(
                          expanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                          size: 16,
                          color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Admin info ────────────────────────────
                AnimatedOpacity(
                  opacity: expanded ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: const BoxDecoration(
                            gradient: ZynkGradients.brand, shape: BoxShape.circle),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 22)),
                      const SizedBox(height: 6),
                      Text(adminName.split(' ').first,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                              color: dark ? ZynkColors.darkText : ZynkColors.lightText),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: ZynkColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20)),
                        child: const Text('ADMIN',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800,
                                color: ZynkColors.primary, letterSpacing: 1))),
                    ]),
                  ),
                ),

                if (expanded) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(height: 1,
                        color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder)),
                ],
                const SizedBox(height: 8),

                // ── Nav items ─────────────────────────────
                _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard',
                    selected: selectedIndex == 0, expanded: expanded,
                    onTap: () => onSelect(0), dark: dark),
                _NavItem(icon: Icons.pending_actions_rounded, label: 'Approvals',
                    selected: selectedIndex == 1, expanded: expanded,
                    badge: pendingCount > 0 ? pendingCount : null,
                    onTap: () => onSelect(1), dark: dark),
                _NavItem(icon: Icons.bar_chart_rounded, label: 'Analytics',
                    selected: selectedIndex == 2, expanded: expanded,
                    onTap: () => onSelect(2), dark: dark),

                const Spacer(),

                _NavItem(icon: Icons.logout_rounded, label: 'Logout',
                    selected: false, expanded: expanded,
                    onTap: onLogout, dark: dark, danger: true),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item — uses fixed layout, NO Row with unbounded children
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final bool     expanded;
  final int?     badge;
  final VoidCallback onTap;
  final bool     dark;
  final bool     danger;

  const _NavItem({
    required this.icon, required this.label,
    required this.selected, required this.expanded,
    required this.onTap, required this.dark,
    this.badge, this.danger = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger
        ? ZynkColors.error
        : widget.selected
            ? ZynkColors.primary
            : widget.dark ? ZynkColors.darkMuted : ZynkColors.lightMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? ZynkColors.primary.withOpacity(0.12)
                : _hovered
                    ? (widget.dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2)
                        .withOpacity(0.8)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: widget.selected
                ? Border.all(color: ZynkColors.primary.withOpacity(0.25))
                : null,
          ),
          // ── Use Stack layout instead of Row to avoid overflow ──
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Icon — always at left
              SizedBox(
                width: 20, height: 20,
                child: Icon(widget.icon, color: color, size: 19),
              ),

              // Badge on icon
              if (widget.badge != null)
                Positioned(
                  top: -5, left: 12,
                  child: Container(
                    width: 15, height: 15,
                    decoration: const BoxDecoration(
                        color: ZynkColors.error, shape: BoxShape.circle),
                    child: Center(child: Text(
                      widget.badge! > 9 ? '9+' : '${widget.badge}',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 7, fontWeight: FontWeight.w800))))),

              // Label — positioned to the right of icon, fades with expanded
              Positioned(
                left: 28, top: 0, bottom: 0,
                child: AnimatedOpacity(
                  opacity: widget.expanded ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(widget.label,
                      style: TextStyle(
                        color: color,
                        fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13),
                      overflow: TextOverflow.ellipsis),
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

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Content
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final String adminName;
  final int totalEvents, totalUsers, pendingCount;
  final VoidCallback onCreateEvent, onApprovals, onAnalytics;
  final bool dark;

  const _DashboardContent({
    required this.adminName, required this.totalEvents,
    required this.totalUsers, required this.pendingCount,
    required this.onCreateEvent, required this.onApprovals,
    required this.onAnalytics, required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ZYNKUP ADMIN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                  letterSpacing: 2.5, color: ZynkColors.primary)),
          const SizedBox(height: 4),
          Text('Hey, ${adminName.split(' ').first} 👋',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: dark ? ZynkColors.darkText : ZynkColors.lightText)),

          const SizedBox(height: 24),

          // Stats
          Row(children: [
            Expanded(child: _StatCard('Events', totalEvents,
                Icons.event_rounded, ZynkColors.primary, dark)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard('Users', totalUsers,
                Icons.people_rounded, ZynkColors.catTech, dark)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard('Pending', pendingCount,
                Icons.pending_actions_rounded, ZynkColors.warning, dark,
                highlight: pendingCount > 0)),
          ]),

          const SizedBox(height: 28),

          Text('QUICK ACTIONS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
          const SizedBox(height: 12),

          _ActionBtn(label: 'Create New Event', sublabel: 'Publish a new campus event',
              icon: Icons.add_circle_rounded, gradient: ZynkGradients.brand,
              isPrimary: true, onTap: onCreateEvent),

          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: _ActionBtn(label: 'Approvals',
                sublabel: pendingCount > 0 ? '$pendingCount waiting' : 'All clear',
                icon: Icons.rule_rounded, color: ZynkColors.warning,
                badge: pendingCount > 0 ? pendingCount : null, onTap: onApprovals)),
            const SizedBox(width: 12),
            Expanded(child: _ActionBtn(label: 'Analytics',
                sublabel: 'Stats & insights',
                icon: Icons.bar_chart_rounded, color: ZynkColors.catTech,
                onTap: onAnalytics)),
          ]),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label; final int value;
  final IconData icon; final Color color;
  final bool dark; final bool highlight;
  const _StatCard(this.label, this.value, this.icon, this.color, this.dark,
      {this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlight ? color.withOpacity(0.4)
            : (dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
        width: highlight ? 1.5 : 1),
      boxShadow: highlight ? [BoxShadow(color: color.withOpacity(0.15),
          blurRadius: 16, offset: const Offset(0, 4))] : null),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 10),
      Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
          color: color, letterSpacing: -1)),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
          color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
    ]));
}

class _ActionBtn extends StatefulWidget {
  final String label, sublabel;
  final IconData icon;
  final LinearGradient? gradient;
  final Color? color;
  final bool isPrimary;
  final int? badge;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.sublabel,
      required this.icon, required this.onTap, this.gradient, this.color,
      this.isPrimary = false, this.badge});
  @override State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false, _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.gradient != null ? Colors.white : widget.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown:  (_) => setState(() => _pressed = true),
        onTapUp:    (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: ()  => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : _hovered ? 1.015 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.all(widget.isPrimary ? 18 : 14),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              color: widget.color != null
                  ? widget.color!.withOpacity(_hovered ? 0.18 : 0.1) : null,
              borderRadius: BorderRadius.circular(16),
              border: widget.gradient == null
                  ? Border.all(color: widget.color!.withOpacity(_hovered ? 0.5 : 0.25),
                      width: 1.5) : null,
              boxShadow: widget.isPrimary && _hovered
                  ? [BoxShadow(color: ZynkColors.primary.withOpacity(0.3),
                      blurRadius: 20, offset: const Offset(0, 6))] : null),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: widget.isPrimary ? 44 : 38,
                  height: widget.isPrimary ? 44 : 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(widget.gradient != null ? 0.2 : 0.0),
                    borderRadius: BorderRadius.circular(11)),
                  child: Icon(widget.icon, color: iconColor,
                      size: widget.isPrimary ? 24 : 20)),
                if (widget.badge != null)
                  Positioned(top: -4, right: -4,
                    child: Container(width: 18, height: 18,
                      decoration: const BoxDecoration(
                          color: ZynkColors.error, shape: BoxShape.circle),
                      child: Center(child: Text('${widget.badge}',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 9, fontWeight: FontWeight.w800))))),
              ]),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.label, style: TextStyle(
                    color: widget.gradient != null ? Colors.white : widget.color,
                    fontWeight: FontWeight.w700,
                    fontSize: widget.isPrimary ? 15 : 13)),
                const SizedBox(height: 2),
                Text(widget.sublabel, style: TextStyle(
                    color: widget.gradient != null
                        ? Colors.white.withOpacity(0.75)
                        : widget.color!.withOpacity(0.7),
                    fontSize: 11)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, size: 13,
                  color: widget.gradient != null
                      ? Colors.white.withOpacity(0.6)
                      : widget.color!.withOpacity(0.5)),
            ]),
          ),
        ),
      ),
    );
  }
}