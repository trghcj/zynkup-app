import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final notifs = await ApiService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifs;
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final success = await ApiService.markAllRead();
    if (success && mounted) {
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
    }
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 7) return '${d.month}/${d.day}/${d.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'EVENT_JOINED':
        return Icons.event_available_rounded;
      case 'NEW_COMMENT':
      case 'NEW_REPLY':
        return Icons.comment_rounded;
      case 'ATTENDANCE_MARKED':
        return Icons.how_to_reg_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'EVENT_JOINED':
      case 'ATTENDANCE_MARKED':
        return ZynkColors.accentGlow;
      case 'NEW_COMMENT':
        return ZynkColors.primary;
      default:
        return ZynkColors.offWhite;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(
        backgroundColor: ZynkColors.darkBg,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(color: ZynkColors.offWhite)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: ZynkColors.darkMuted),
            onPressed: _markAllRead,
            tooltip: 'Mark all as read',
          )
        ],
        iconTheme: const IconThemeData(color: ZynkColors.offWhite),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZynkColors.gold))
          : _notifications.isEmpty
              ? const Center(
                  child: Text(
                    'No notifications yet.',
                    style: TextStyle(color: ZynkColors.darkMuted),
                  ),
                )
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: ZynkColors.darkBorder,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final isRead = notif['is_read'] == true;
                    final createdStr = notif['created_at'];
                    final createdAt = createdStr != null 
                        ? DateTime.tryParse(createdStr)?.toLocal() ?? DateTime.now()
                        : DateTime.now();

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      tileColor: isRead ? Colors.transparent : ZynkColors.darkSurface,
                      leading: CircleAvatar(
                        backgroundColor: _getColorForType(notif['type']).withValues(alpha: 0.2),
                        child: Icon(
                          _getIconForType(notif['type']),
                          color: _getColorForType(notif['type']),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        notif['title'] ?? 'Notification',
                        style: TextStyle(
                          color: isRead ? ZynkColors.offWhite : Colors.white,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            notif['content'] ?? '',
                            style: TextStyle(
                              color: isRead ? ZynkColors.darkMuted : ZynkColors.offWhite,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _timeAgo(createdAt),
                            style: const TextStyle(
                              color: ZynkColors.darkMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!isRead) {
                          ApiService.markNotificationRead(notif['id']);
                          setState(() {
                            notif['is_read'] = true;
                          });
                        }
                      },
                    );
                  },
                ),
    );
  }
}
