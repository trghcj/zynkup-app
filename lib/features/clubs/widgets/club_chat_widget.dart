import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';

class ClubChatWidget extends StatefulWidget {
  final int clubId;

  const ClubChatWidget({super.key, required this.clubId});

  @override
  State<ClubChatWidget> createState() => _ClubChatWidgetState();
}

class _ClubChatWidgetState extends State<ClubChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  WebSocketChannel? _channel;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadHistoryAndConnect();
  }

  Future<void> _loadHistoryAndConnect() async {
    final profile = await ApiService.getCurrentUser();
    if (profile != null) {
      _currentUserId = int.tryParse(profile['id']?.toString() ?? '');
    }

    final history = await ApiService.getClubChatHistory(widget.clubId);
    if (mounted) {
      setState(() {
        _messages.addAll(history.cast<Map<String, dynamic>>());
        if (_messages.isNotEmpty) {
          _messages.insert(0, {'type': 'divider', 'text': 'Unread messages'});
        }
        _loading = false;
      });
      _connectWebSocket();
    }
  }

  void _connectWebSocket() {
    final url = ApiService.getClubChatWebSocketUrl(widget.clubId);
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen((message) {
      if (mounted) {
        setState(() {
          final data = jsonDecode(message);
          _messages.insert(0, data);
        });
      }
    }, onError: (err) {
      // Handle error
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty && _channel != null) {
      _channel!.sink.add(text);
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ZynkColors.gold));
    }
    
    if (!ApiService.hasToken) {
      return const Center(child: Text("Please log in to chat", style: TextStyle(color: ZynkColors.darkMuted)));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              if (msg['type'] == 'divider') {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: ZynkColors.darkMuted.withValues(alpha: 0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(msg['text'], style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                      Expanded(child: Divider(color: ZynkColors.darkMuted.withValues(alpha: 0.3))),
                    ],
                  ),
                );
              }
              final isMe = _currentUserId != null && msg['user_id'] == _currentUserId;
              final name = msg['user_name'] ?? 'User';
              final avatar = msg['user_avatar'] ?? 'https://api.dicebear.com/7.x/avataaars/png?seed=$name';
              final content = msg['content'] ?? '';
              
              final role = msg['user_role'] ?? 'member';
              
              DateTime? dt;
              try { dt = DateTime.parse(msg['created_at']).toLocal(); } catch(_) {}
              final timeStr = dt != null ? DateFormat('h:mm a').format(dt) : '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      CircleAvatar(radius: 14, backgroundImage: NetworkImage(avatar)),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? ZynkColors.gold : ZynkColors.darkSurface2,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(ZynkRadius.md),
                            topRight: const Radius.circular(ZynkRadius.md),
                            bottomLeft: isMe ? const Radius.circular(ZynkRadius.md) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(ZynkRadius.md),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(name, style: TextStyle(color: isMe ? Colors.black54 : ZynkColors.darkMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: role == 'admin' ? (isMe ? Colors.black12 : ZynkColors.gold.withValues(alpha: 0.2)) : Colors.white10,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(role.toUpperCase(), style: TextStyle(color: role == 'admin' ? (isMe ? Colors.black87 : ZynkColors.gold) : (isMe ? Colors.black54 : Colors.white70), fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Text(content, style: TextStyle(color: isMe ? Colors.black87 : ZynkColors.offWhite)),
                            const SizedBox(height: 4),
                            Text(timeStr, style: TextStyle(color: isMe ? Colors.black54 : ZynkColors.darkMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      CircleAvatar(radius: 14, backgroundImage: NetworkImage(avatar)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ZynkColors.darkBg,
            border: Border(top: BorderSide(color: ZynkColors.darkBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: ZynkColors.offWhite),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: ZynkColors.darkMuted),
                    filled: true,
                    fillColor: ZynkColors.darkSurface2,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ZynkRadius.pill),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: ZynkColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.black87, size: 20),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
