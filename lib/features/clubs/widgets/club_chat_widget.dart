import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:url_launcher/url_launcher.dart';

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
      final payload = {
        'content': text
      };
      _channel!.sink.add(jsonEncode(payload));
      _messageController.clear();
    }
  }

  Future<void> _showAttachmentPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZynkColors.darkSurface,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: ZynkColors.gold),
                title: const Text('Upload Image', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAttachment(fp.FileType.image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file, color: ZynkColors.gold),
                title: const Text('Upload Document', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAttachment(fp.FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions, color: ZynkColors.gold),
                title: const Text('Send Sticker', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showStickerPicker();
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _showStickerPicker() {
    final predefinedStickers = [
      'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Fire.png',
      'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Thumbs%20Up.png',
      'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Party%20Popper.png',
      'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Red%20Heart.png',
      'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Grinning%20Face%20with%20Big%20Eyes.png',
      'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Face%20with%20Tears%20of%20Joy.png',
      'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Rocket.png',
      'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Star-Struck.png',
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: ZynkColors.darkSurface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: predefinedStickers.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendSticker(predefinedStickers[index]);
                  },
                  child: Image.network(predefinedStickers[index]),
                );
              },
            ),
          ),
        );
      }
    );
  }

  void _sendSticker(String url) {
    if (_channel != null) {
      final payload = {
        'content': '',
        'attachment_url': url,
        'attachment_type': 'sticker'
      };
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  Future<void> _pickAndUploadAttachment(fp.FileType type, {List<String>? allowedExtensions}) async {
    final result = await fp.FilePicker.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.size > 10 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File must be smaller than 10MB')));
      return;
    }

    final uploadRes = await ApiService.uploadClubChatAttachment(widget.clubId, file.bytes!, file.name);
    if (uploadRes != null && _channel != null) {
      final payload = {
        'content': '',
        'attachment_url': uploadRes['url'],
        'attachment_type': uploadRes['type']
      };
      _channel!.sink.add(jsonEncode(payload));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
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
                            if (content.isNotEmpty)
                              Text(content, style: TextStyle(color: isMe ? Colors.black87 : ZynkColors.offWhite)),
                            if (msg['attachment_url'] != null) ...[
                               const SizedBox(height: 8),
                               if (msg['attachment_type'] == 'image' || msg['attachment_type'] == 'sticker' || msg['attachment_type'] == 'gif')
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(msg['attachment_url'], height: 150, fit: BoxFit.cover),
                                  )
                               else
                                  GestureDetector(
                                    onTap: () => launchUrl(Uri.parse(msg['attachment_url'])),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.insert_drive_file, color: isMe ? Colors.black54 : Colors.white70, size: 20),
                                          const SizedBox(width: 8),
                                          Text('View Document', style: TextStyle(color: isMe ? Colors.black87 : Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                            ],
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
              GestureDetector(
                onTap: _showAttachmentPicker,
                child: const Icon(Icons.attach_file, color: ZynkColors.darkMuted),
              ),
              const SizedBox(width: 8),
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
