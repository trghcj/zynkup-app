import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class EventParticipantsScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventParticipantsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<EventParticipantsScreen> createState() => _EventParticipantsScreenState();
}

class _EventParticipantsScreenState extends State<EventParticipantsScreen> {
  List<dynamic> _participants = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    try {
      final data = await ApiService.getEventParticipants(widget.eventId);
      if (mounted) {
        setState(() {
          _participants = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load participants';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(
        backgroundColor: ZynkColors.darkBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Participants',
              style: TextStyle(color: ZynkColors.offWhite, fontSize: 18),
            ),
            Text(
              widget.eventTitle,
              style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: ZynkColors.offWhite),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZynkColors.gold))
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : _participants.isEmpty
                  ? const Center(
                      child: Text(
                        'No participants registered yet.',
                        style: TextStyle(color: ZynkColors.darkMuted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _participants.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: ZynkColors.darkBorder,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final p = _participants[index];
                        final bool attended = p['attended'] == true;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: ZynkColors.darkSurface,
                            backgroundImage: p['avatar_url'] != null
                                ? NetworkImage(p['avatar_url'])
                                : null,
                            child: p['avatar_url'] == null
                                ? const Icon(Icons.person, color: ZynkColors.darkMuted)
                                : null,
                          ),
                          title: Text(
                            p['name'] ?? 'Unknown',
                            style: const TextStyle(
                              color: ZynkColors.offWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            p['email'] ?? '',
                            style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 13),
                          ),
                          trailing: attended
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ZynkColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ZynkColors.success.withValues(alpha: 0.5)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: ZynkColors.success, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: ZynkColors.success,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const Text(
                                  'Registered',
                                  style: TextStyle(color: ZynkColors.darkMuted, fontSize: 12),
                                ),
                        );
                      },
                    ),
    );
  }
}
