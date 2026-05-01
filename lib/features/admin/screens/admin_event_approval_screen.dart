// lib/features/admin/screens/admin_event_approval_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class AdminEventApprovalScreen extends StatefulWidget {
  const AdminEventApprovalScreen({super.key});

  @override
  State<AdminEventApprovalScreen> createState() =>
      _AdminEventApprovalScreenState();
}

class _AdminEventApprovalScreenState
    extends State<AdminEventApprovalScreen>
    with SingleTickerProviderStateMixin {
  List<Event> _pendingEvents = [];
  List<Event> _allEvents     = [];
  bool _isLoading   = true;
  String? _processingId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final pending = await ApiService.getPendingEvents();
      final all    = await ApiService.getEvents(force: true);
      if (mounted) {
        setState(() {
          _pendingEvents = pending
              .map((e) => Event.fromJson(e as Map<String, dynamic>))
              .toList();
          _allEvents = all
              .map((e) => Event.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(String eventId) async {
    setState(() => _processingId = eventId);
    final ok = await ApiService.approveEvent(int.parse(eventId));
    if (ok && mounted) {
      _showSnack('Event approved ✅', ZynkColors.success);
      await _fetchAll();
    }
    if (mounted) setState(() => _processingId = null);
  }

  Future<void> _reject(String eventId) async {
    final confirm = await _confirmDialog(
        'Reject Event', 'This will permanently delete the event.');
    if (confirm != true) return;

    final ok = await ApiService.rejectEvent(int.parse(eventId));
    if (ok && mounted) {
      _showSnack('Event rejected ❌', ZynkColors.error);
      await _fetchAll();
    }
  }

  Future<void> _deleteEvent(String eventId, String title) async {
    final confirm = await _confirmDialog(
        'Delete Event', 'Delete "$title"? This cannot be undone.');
    if (confirm != true) return;

    final ok = await ApiService.deleteEvent(int.parse(eventId));
    if (ok && mounted) {
      _showSnack('Event deleted', ZynkColors.error);
      await _fetchAll();
    }
  }

  Future<bool?> _confirmDialog(String title, String body) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ZynkColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Management'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: ZynkColors.primary,
          unselectedLabelColor:
              dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
          indicatorColor: ZynkColors.primary,
          tabs: [
            Tab(text: 'Pending (${_pendingEvents.length})'),
            Tab(text: 'All Events (${_allEvents.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child:
                  CircularProgressIndicator(color: ZynkColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingList(dark),
                _buildAllEventsList(dark),
              ],
            ),
    );
  }

  Widget _buildPendingList(bool dark) {
    if (_pendingEvents.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 72, height: 72,
              decoration: BoxDecoration(
                  color: ZynkColors.success.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded,
                  color: ZynkColors.success, size: 36)),
          const SizedBox(height: 14),
          Text('All caught up!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: dark ? ZynkColors.darkText : ZynkColors.lightText)),
          Text('No pending approvals',
              style: TextStyle(
                  color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
        ]),
      );
    }

    return RefreshIndicator(
      color: ZynkColors.primary,
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingEvents.length,
        itemBuilder: (_, i) =>
            _EventCard(
              event: _pendingEvents[i],
              isProcessing: _processingId == _pendingEvents[i].id,
              dark: dark,
              onApprove: () => _approve(_pendingEvents[i].id),
              onReject:  () => _reject(_pendingEvents[i].id),
            ),
      ),
    );
  }

  Widget _buildAllEventsList(bool dark) {
    if (_allEvents.isEmpty) {
      return Center(child: Text('No approved events yet',
          style: TextStyle(
              color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)));
    }

    final past     = _allEvents.where(
        (e) => e.date.isBefore(DateTime.now())).toList();
    final upcoming = _allEvents.where(
        (e) => !e.date.isBefore(DateTime.now())).toList();

    return RefreshIndicator(
      color: ZynkColors.primary,
      onRefresh: _fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (upcoming.isNotEmpty) ...[
            _listLabel('Upcoming', ZynkColors.success, dark),
            ...upcoming.map((e) => _AllEventTile(
              event: e, dark: dark,
              onDelete: () => _deleteEvent(e.id, e.title),
            )),
            const SizedBox(height: 16),
          ],
          if (past.isNotEmpty) ...[
            _listLabel('Past Events', ZynkColors.lightMuted, dark),
            ...past.map((e) => _AllEventTile(
              event: e, dark: dark,
              onDelete: () => _deleteEvent(e.id, e.title),
              isPast: true,
            )),
          ],
        ],
      ),
    );
  }

  Widget _listLabel(String label, Color color, bool dark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: color, letterSpacing: 0.5)),
    ]));
}

// ── Pending event card ────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isProcessing, dark;
  final VoidCallback onApprove, onReject;

  const _EventCard({
    required this.event, required this.isProcessing,
    required this.dark, required this.onApprove, required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image
        if (event.imageUrls.isNotEmpty)
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 160, width: double.infinity,
              child: _SmartImage(url: event.imageUrls.first)),
          )
        else
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              height: 80, width: double.infinity,
              decoration: BoxDecoration(
                  gradient: ZynkGradients.forCategory(event.category.name)),
              child: const Icon(Icons.event_rounded,
                  color: Colors.white30, size: 36)),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryBadge(event.category.name),
              const SizedBox(height: 8),
              Text(event.title, style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: dark ? ZynkColors.darkText : ZynkColors.lightText)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 13,
                    color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
                const SizedBox(width: 5),
                Text(DateFormat('MMM dd • hh:mm a').format(event.date),
                    style: TextStyle(fontSize: 12,
                        color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on_rounded, size: 13,
                    color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
                const SizedBox(width: 5),
                Expanded(child: Text(event.venue,
                    style: TextStyle(fontSize: 12,
                        color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
                    overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: ZynkButton(
                  label: 'Approve', icon: Icons.check_rounded,
                  bgColor: ZynkColors.success, height: 42,
                  isLoading: isProcessing,
                  onTap: isProcessing ? null : onApprove,
                )),
                const SizedBox(width: 10),
                Expanded(child: ZynkButton(
                  label: 'Reject', icon: Icons.close_rounded,
                  bgColor: ZynkColors.error, height: 42,
                  isLoading: false,
                  onTap: isProcessing ? null : onReject,
                )),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── All events tile ───────────────────────────────────────────────────────────

class _AllEventTile extends StatelessWidget {
  IconData _catIcon(EventCategory cat) {
  switch (cat) {
    case EventCategory.tech:
      return Icons.computer_rounded;
    case EventCategory.cultural:
      return Icons.palette_rounded;
    case EventCategory.sports:
      return Icons.sports_rounded;
    case EventCategory.workshop:
      return Icons.build_rounded;
    case EventCategory.seminar:
      return Icons.school_rounded;
    // ignore: unreachable_switch_default
    default:
      return Icons.event;
  }
}
  final Event event;
  final bool dark, isPast;
  final VoidCallback onDelete;

  const _AllEventTile({
    required this.event,
    required this.dark,
    required this.onDelete,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isPast ? 0.7 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPast
                ? (dark ? ZynkColors.darkBorder : ZynkColors.lightBorder)
                    .withOpacity(0.5)
                : (dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ZynkColors.forCategory(event.category.name)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _catIcon(event.category),
                color: ZynkColors.forCategory(event.category.name),
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: dark
                          ? ZynkColors.darkText
                          : ZynkColors.lightText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(event.date),
                    
                    style: TextStyle(
                      fontSize: 12,
                      color: dark
                          ? ZynkColors.darkMuted
                          : ZynkColors.lightMuted,
                    ),
                  ),
                  
                  Text(
  "${event.registeredUsers.length} Registered",
  style: TextStyle(
    fontSize: 12,
    color: dark
        ? ZynkColors.darkMuted
        : ZynkColors.lightMuted,
  ),
),
                ],
              ),
            ),

            Row(
  children: [
    GestureDetector(
      onTap: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ZynkColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZynkColors.error.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.delete_rounded, color: ZynkColors.error, size: 14),
            SizedBox(width: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: ZynkColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),

    const SizedBox(width: 6),

    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ZynkColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'APPROVED',
        style: TextStyle(
          color: ZynkColors.success,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    ),
  ],
),
],
),
      ),
    ); 
  }
}

// ── Smart image widget (handles base64 + URL) ─────────────────────────────────

class _SmartImage extends StatelessWidget {
  final String url;
  const _SmartImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity);
      } catch (_) {
        return _placeholder();
      }
    }
    return Image.network(url, fit: BoxFit.cover, width: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() => Container(
    color: ZynkColors.darkSurface2,
    child: const Center(child: Icon(Icons.broken_image_rounded,
        color: Colors.white38, size: 36)));
}