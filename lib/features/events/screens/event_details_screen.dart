import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import '../models/event_model.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;
  final bool isAdmin; // pass true from admin screens

  const EventDetailsScreen({
    super.key,
    required this.event,
    this.isAdmin = false,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late Event event;
  bool _isLoading    = true;
  bool _registering  = false;
  bool _registered   = false;
  int  _attendeeCount = 0;

  @override
  void initState() {
    super.initState();
    event = widget.event;
    _fetchEvent();
  }

  // ── Fetch fresh event data from server ────────────────────────────────────
  Future<void> _fetchEvent() async {
    try {
      final data = await ApiService.getEvent(int.parse(event.id));
      if (data != null && data is Map<String, dynamic> && mounted) {
        setState(() {
          event = Event.fromJson(data);
          _attendeeCount = data["attendee_count"] as int? ?? 0;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<void> _register() async {
    setState(() => _registering = true);
    try {
      final success = await ApiService.registerEvent(int.parse(event.id));
      if (!mounted) return;
      if (success) {
        setState(() {
          _registered = true;
          _attendeeCount++;
        });
        _snack('Registered successfully! 🎉', ZynkColors.success);
      }
    } on ApiException catch (e) {
      _snack(e.message, ZynkColors.error);
    } catch (_) {
      _snack('Registration failed. Please try again.', ZynkColors.error);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  // ── Admin: delete event ───────────────────────────────────────────────────
  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: ZynkColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.rejectEvent(int.parse(event.id));
      if (mounted) Navigator.pop(context, true); // signal refresh
    } on ApiException catch (e) {
      _snack(e.message, ZynkColors.error);
    }
  }

  // ── Admin: approve event ──────────────────────────────────────────────────
  Future<void> _approveEvent() async {
    try {
      await ApiService.approveEvent(int.parse(event.id));
      _snack('Event approved ✅', ZynkColors.success);
      _fetchEvent();
    } on ApiException catch (e) {
      _snack(e.message, ZynkColors.error);
    }
  }

  // ── Open registration form URL ────────────────────────────────────────────
  Future<void> _openRegistrationForm() async {
    final url = event.registrationUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Could not open form link.', ZynkColors.error);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cat  = event.category.name;
    final isUpcoming = event.date.isAfter(DateTime.now());

    // QR data: use registration URL if available, else event URL
    final qrData = (event.registrationUrl?.isNotEmpty == true)
        ? event.registrationUrl!
        : 'https://zynkup-app.netlify.app/events/${event.id}';

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: ZynkColors.primary))
          : CustomScrollView(
              slivers: [
                // ── Hero banner ──────────────────────────────────
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: dark ? ZynkColors.darkSurface : ZynkColors.lightBg,
                  iconTheme: const IconThemeData(color: Colors.white),
                  // Admin gets delete button, users get nothing
                  actions: widget.isAdmin
                      ? [
                          IconButton(
                            icon: const Icon(Icons.delete_rounded),
                            tooltip: 'Delete Event',
                            onPressed: _deleteEvent,
                          ),
                        ]
                      : [],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(fit: StackFit.expand, children: [
                      // Image or gradient
                      event.imageUrls.isNotEmpty
                          ? Image.network(
                              event.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                    gradient: ZynkGradients.forCategory(cat)),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                  gradient: ZynkGradients.forCategory(cat)),
                            ),
                      // Dark overlay for readability
                      Container(color: Colors.black.withOpacity(0.35)),
                      // Title overlay
                      Positioned(
                        left: 20, right: 20, bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CategoryBadge(cat),
                            const SizedBox(height: 8),
                            Text(event.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                )),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Pending banner (admin only) ───────────
                        if (widget.isAdmin && !event.isApproved)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ZynkColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: ZynkColors.warning.withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.pending_actions_rounded,
                                  color: ZynkColors.warning),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('Pending Approval',
                                  style: TextStyle(
                                      color: ZynkColors.warning,
                                      fontWeight: FontWeight.w700))),
                              TextButton(
                                onPressed: _approveEvent,
                                child: const Text('Approve',
                                    style: TextStyle(
                                        color: ZynkColors.success,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ]),
                          ),

                        // ── Status + attendees ─────────────────────
                        Row(children: [
                          _StatusBadge(isUpcoming: isUpcoming),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: ZynkColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(children: [
                              const Icon(Icons.people_rounded,
                                  size: 14, color: ZynkColors.primary),
                              const SizedBox(width: 5),
                              Text('$_attendeeCount registered',
                                  style: const TextStyle(
                                    color: ZynkColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ]),
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // ── Description ───────────────────────────
                        Text('About this Event',
                            style: TextStyle(
                              color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                              fontSize: 16, fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(height: 8),
                        Text(event.description,
                            style: TextStyle(
                              color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                              fontSize: 15, height: 1.65,
                            )),

                        const SizedBox(height: 20),

                        // ── Info cards ────────────────────────────
                        _InfoCard(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date & Time',
                          value: DateFormat('EEE, MMM dd yyyy • hh:mm a')
                              .format(event.date),
                          color: ZynkColors.catTech, dark: dark,
                        ),
                        const SizedBox(height: 10),
                        _InfoCard(
                          icon: Icons.location_on_rounded,
                          label: 'Venue',
                          value: event.venue,
                          color: ZynkColors.primary, dark: dark,
                        ),
                        const SizedBox(height: 10),
                        _InfoCard(
                          icon: Icons.category_rounded,
                          label: 'Category',
                          value: cat.toUpperCase(),
                          color: ZynkColors.forCategory(cat), dark: dark,
                        ),

                        const SizedBox(height: 24),

                        // ── QR Code ────────────────────────────────
                        // QR contains the registration form URL so scanning opens the form
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
                          ),
                          child: Column(children: [
                            Text('Event QR Code',
                                style: TextStyle(
                                  color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                                  fontWeight: FontWeight.w700, fontSize: 15,
                                )),
                            const SizedBox(height: 6),
                            Text(
                              event.registrationUrl?.isNotEmpty == true
                                  ? 'Scan to open registration form'
                                  : 'Scan to view event page',
                              style: TextStyle(
                                  color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            QrImageView(
                              data: qrData,
                              size: 200,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(10),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 24),

                        // ── Register / Open Form buttons ───────────
                        if (isUpcoming && !widget.isAdmin) ...[
                          // Open form button (if form URL exists)
                          if (event.registrationUrl?.isNotEmpty == true) ...[
                            ZynkButton(
                              label: 'Open Registration Form',
                              icon: Icons.open_in_new_rounded,
                              onTap: _openRegistrationForm,
                              bgColor: ZynkColors.accent,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Register button (marks attendance in app)
                          _registered
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: ZynkColors.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: ZynkColors.success.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          color: ZynkColors.success),
                                      SizedBox(width: 8),
                                      Text('You are registered!',
                                          style: TextStyle(
                                            color: ZynkColors.success,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          )),
                                    ],
                                  ),
                                )
                              : ZynkButton(
                                  label: 'Register for Event',
                                  icon: Icons.how_to_reg_rounded,
                                  onTap: _register,
                                  isLoading: _registering,
                                ),
                        ],

                        if (!isUpcoming && !widget.isAdmin)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy_rounded,
                                    color: ZynkColors.lightMuted),
                                SizedBox(width: 8),
                                Text('This event has ended',
                                    style: TextStyle(
                                        color: ZynkColors.lightMuted,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isUpcoming;
  const _StatusBadge({required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    final c = isUpcoming ? ZynkColors.success : ZynkColors.lightMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(isUpcoming ? Icons.schedule_rounded : Icons.history_rounded,
            size: 13, color: c),
        const SizedBox(width: 5),
        Text(isUpcoming ? 'Upcoming' : 'Past Event',
            style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final bool dark;
  const _InfoCard({required this.icon, required this.label,
    required this.value, required this.color, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
              color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
              fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3,
            )),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(
              color: dark ? ZynkColors.darkText : ZynkColors.lightText,
              fontSize: 14, fontWeight: FontWeight.w600,
            )),
          ],
        )),
      ]),
    );
  }
}