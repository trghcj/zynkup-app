// lib/features/admin/screens/admin_event_approval_screen.dart
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
    extends State<AdminEventApprovalScreen> {
  List<Event> _events = [];
  bool _isLoading = true;
  Set<int> _processing = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      // Uses ApiService which sends Bearer token automatically
      final data = await ApiService.getPendingEvents();
      if (mounted) {
        setState(() {
          _events = data
              .map<Event>((e) => Event.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(int eventId) async {
    setState(() => _processing.add(eventId));
    try {
      final ok = await ApiService.approveEvent(eventId);
      if (ok && mounted) {
        _snack("Event approved ✅", ZynkColors.success);
        await _fetch();
      }
    } catch (_) {
      _snack("Failed to approve", ZynkColors.error);
    } finally {
      if (mounted) setState(() => _processing.remove(eventId));
    }
  }

  Future<void> _reject(int eventId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Event',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Permanently delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ZynkColors.error,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processing.add(eventId));
    try {
      final ok = await ApiService.rejectEvent(eventId);
      if (ok && mounted) {
        _snack("Event rejected", ZynkColors.error);
        await _fetch();
      }
    } catch (_) {
      _snack("Failed to reject", ZynkColors.error);
    } finally {
      if (mounted) setState(() => _processing.remove(eventId));
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        actions: [
          // Count badge
          if (_events.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ZynkColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ZynkColors.warning.withOpacity(0.4)),
              ),
              child: Text(
                '${_events.length} pending',
                style: const TextStyle(
                    color: ZynkColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: ZynkColors.primary))
          : RefreshIndicator(
              color: ZynkColors.primary,
              onRefresh: _fetch,
              child: _events.isEmpty
                  ? _emptyState(dark)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _events.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 14),
                      itemBuilder: (_, i) =>
                          _EventCard(
                        event: _events[i],
                        isProcessing: _processing
                            .contains(int.tryParse(_events[i].id) ?? -1),
                        onApprove: () => _approve(
                            int.parse(_events[i].id)),
                        onReject: () => _reject(
                            int.parse(_events[i].id), _events[i].title),
                      ),
                    ),
            ),
    );
  }

  Widget _emptyState(bool dark) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: ZynkColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: ZynkColors.success, size: 40),
        ),
        const SizedBox(height: 16),
        Text('All caught up!',
            style: TextStyle(
                color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        const SizedBox(height: 4),
        Text('No pending approvals',
            style: TextStyle(
                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                fontSize: 14)),
      ]),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _EventCard({
    required this.event,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cat = event.category.name;

    return Container(
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: ZynkColors.primary.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Image / category header ──────────────────────────
        Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: ZynkGradients.forCategory(cat),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Stack(children: [
            Center(
              child: Icon(Icons.event_rounded,
                  color: Colors.white.withOpacity(0.3), size: 60),
            ),
            Positioned(
              top: 12, left: 14,
              child: CategoryBadge(cat),
            ),
            Positioned(
              top: 10, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.pending_rounded,
                      color: ZynkColors.accentLight, size: 12),
                  const SizedBox(width: 4),
                  const Text('Pending',
                      style: TextStyle(
                          color: ZynkColors.accentLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Content ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(event.title,
                style: TextStyle(
                  color:
                      dark ? ZynkColors.darkText : ZynkColors.lightText,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                )),

            const SizedBox(height: 8),

            Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 13,
                  color: dark
                      ? ZynkColors.darkMuted
                      : ZynkColors.lightMuted),
              const SizedBox(width: 5),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(event.date),
                style: TextStyle(
                    color: dark
                        ? ZynkColors.darkMuted
                        : ZynkColors.lightMuted,
                    fontSize: 12),
              ),
            ]),

            const SizedBox(height: 4),

            Row(children: [
              Icon(Icons.location_on_rounded,
                  size: 13,
                  color: dark
                      ? ZynkColors.darkMuted
                      : ZynkColors.lightMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(event.venue,
                    style: TextStyle(
                        color: dark
                            ? ZynkColors.darkMuted
                            : ZynkColors.lightMuted,
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),

            const SizedBox(height: 6),

            Text(event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: dark
                        ? ZynkColors.darkMuted
                        : ZynkColors.lightMuted,
                    fontSize: 13,
                    height: 1.4)),

            const SizedBox(height: 14),

            // ── Action buttons ──────────────────────────────
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: isProcessing ? null : onApprove,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: isProcessing
                          ? null
                          : const LinearGradient(colors: [
                              Color(0xFF1A3D2B),
                              ZynkColors.success
                            ]),
                      color: isProcessing
                          ? ZynkColors.success.withOpacity(0.3)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: isProcessing
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text('Approve',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                              ]),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: GestureDetector(
                  onTap: isProcessing ? null : onReject,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: ZynkColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: ZynkColors.error.withOpacity(0.4)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded,
                              color: ZynkColors.error, size: 16),
                          SizedBox(width: 6),
                          Text('Reject',
                              style: TextStyle(
                                  color: ZynkColors.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}