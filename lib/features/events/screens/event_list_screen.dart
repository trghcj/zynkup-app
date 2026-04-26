import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/edit_event_screen.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';

class EventListScreen extends StatefulWidget {
  final EventCategory? category;
  const EventListScreen({super.key, this.category});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  List<Event> _events = [];
  bool _isLoading = true;
  final String baseUrl = "http://127.0.0.1:8000";

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/events"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _events = (data as List).map((e) => Event.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load events");
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      final res = await http.delete(Uri.parse("$baseUrl/events/$id"));
      if (res.statusCode == 200) fetchEvents();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final events = widget.category == null
        ? _events
        : _events.where((e) => e.category == widget.category).toList();

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: ZynkColors.primary));
    }

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 48, color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
            const SizedBox(height: 12),
            Text(
              'No events found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: ZynkColors.primary,
      onRefresh: fetchEvents,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: events.length,
        itemBuilder: (_, index) {
          final event = events[index];
          final catColor = ZynkColors.forCategory(event.category.name);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => EventDetailsScreen(event: event)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // ── Category Color Strip + Icon ───────
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_categoryIcon(event.category),
                          color: catColor, size: 22),
                    ),

                    const SizedBox(width: 12),

                    // ── Info ─────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: dark
                                        ? ZynkColors.darkText
                                        : ZynkColors.lightText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!event.isApproved)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ZynkColors.warning.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'PENDING',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: ZynkColors.warning,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 12,
                                  color: dark
                                      ? ZynkColors.darkMuted
                                      : ZynkColors.lightMuted),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM dd, yyyy • hh:mm a')
                                    .format(event.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dark
                                      ? ZynkColors.darkMuted
                                      : ZynkColors.lightMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 12,
                                  color: dark
                                      ? ZynkColors.darkMuted
                                      : ZynkColors.lightMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.venue,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: dark
                                        ? ZynkColors.darkMuted
                                        : ZynkColors.lightMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Actions ──────────────────────────
                    Column(
                      children: [
                        _iconBtn(
                          icon: Icons.edit_rounded,
                          color: ZynkColors.catTech,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EditEventScreen(event: event)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _iconBtn(
                          icon: Icons.delete_rounded,
                          color: ZynkColors.error,
                          onTap: () => _showDeleteDialog(event),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showDeleteDialog(Event event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event'),
        content: Text("Delete '${event.title}'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteEvent(event.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZynkColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(EventCategory cat) {
    switch (cat) {
      case EventCategory.tech: return Icons.computer_rounded;
      case EventCategory.cultural: return Icons.palette_rounded;
      case EventCategory.sports: return Icons.sports_rounded;
      case EventCategory.workshop: return Icons.build_rounded;
      case EventCategory.seminar: return Icons.school_rounded;
    }
  }
}