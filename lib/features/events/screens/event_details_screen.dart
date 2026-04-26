import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import '../models/event_model.dart';
import 'edit_event_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late Event event;
  bool _isLoading = true;
  bool _registering = false;
  final String baseUrl = "http://127.0.0.1:8000";

  @override
  void initState() {
    super.initState();
    event = widget.event;
    fetchEvent();
  }

  Future<void> fetchEvent() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/events/${event.id}"));
      if (res.statusCode == 200) {
        setState(() {
          event = Event.fromJson(jsonDecode(res.body));
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> register() async {
    setState(() => _registering = true);
    try {
      final res = await http.post(Uri.parse("$baseUrl/events/${event.id}/register"));
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.celebration_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Registered successfully!'),
            ]),
            backgroundColor: ZynkColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _registering = false);
  }

  Future<void> deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ZynkColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await http.delete(Uri.parse("$baseUrl/events/${event.id}"));
    if (res.statusCode == 200 && mounted) Navigator.pop(context);
  }

  Future<void> approveEvent() async {
    final res = await http.put(Uri.parse("$baseUrl/events/${event.id}/approve"));
    if (res.statusCode == 200) fetchEvent();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(event.title)),
        body: Center(child: CircularProgressIndicator(color: ZynkColors.primary)),
      );
    }

    final catColor = ZynkColors.forCategory(event.category.name);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Image / Hero App Bar ─────────────────────────
          SliverAppBar(
            expandedHeight: event.imageUrls.isNotEmpty ? 280 : 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: event.imageUrls.isNotEmpty
                  ? PageView(
                      children: event.imageUrls
                          .map((url) => Image.network(url, fit: BoxFit.cover))
                          .toList(),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: ZynkGradients.forCategory(event.category.name),
                      ),
                      child: const Icon(Icons.event_rounded,
                          color: Colors.white30, size: 80),
                    ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditEventScreen(event: event)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.white),
                onPressed: deleteEvent,
              ),
            ],
          ),

          // ── Content ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status Banner ────────────────────────
                  if (!event.isApproved)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: ZynkColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: ZynkColors.warning.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded,
                              color: ZynkColors.warning, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Pending Approval',
                              style: TextStyle(
                                color: ZynkColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: approveEvent,
                            style: TextButton.styleFrom(
                              foregroundColor: ZynkColors.warning,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              backgroundColor:
                                  ZynkColors.warning.withOpacity(0.15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Approve',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  // ── Category Badge + Title ────────────────
                  CategoryBadge(event.category.name),
                  const SizedBox(height: 10),
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Description ──────────────────────────
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Info Cards ──────────────────────────
                  _infoTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date & Time',
                    value: DateFormat('EEE, MMM dd • hh:mm a').format(event.date),
                    color: catColor,
                    dark: dark,
                  ),
                  const SizedBox(height: 10),
                  _infoTile(
                    icon: Icons.location_on_rounded,
                    label: 'Venue',
                    value: event.venue,
                    color: catColor,
                    dark: dark,
                  ),
                  const SizedBox(height: 10),
                  _infoTile(
                    icon: Icons.people_rounded,
                    label: 'Registered',
                    value: '${event.registeredUsers.length} attendees',
                    color: catColor,
                    dark: dark,
                  ),

                  const SizedBox(height: 28),

                  // ── QR Code ─────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Event QR Code',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          QrImageView(data: event.id, size: 160),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Register Button ──────────────────────
                  if (event.isApproved)
                    ZynkButton(
                      label: 'Register for Event',
                      icon: Icons.how_to_reg_rounded,
                      isLoading: _registering,
                      onTap: register,
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}