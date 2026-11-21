import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:zynkup/core/widgets/full_screen_image_viewer.dart';
import 'package:zynkup/features/profile/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynkup/core/utils/date_utils.dart';
import 'package:zynkup/core/utils/safe_launch.dart';
import 'package:zynkup/core/widgets/poll_composer.dart';

class ClubChatWidget extends StatefulWidget {
  final int clubId;

  const ClubChatWidget({super.key, required this.clubId});

  @override
  State<ClubChatWidget> createState() => _ClubChatWidgetState();
}

class _ClubChatWidgetState extends State<ClubChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  WebSocketChannel? _channel;
  int? _currentUserId;

  // Connection state, so a dropped socket (network switch, phone asleep,
  // server restart) reconnects instead of silently going quiet.
  bool _connected = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

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
        _messages.addAll(history.cast<Map<String, dynamic>>().reversed.toList());
        if (_messages.isNotEmpty) {
          _messages.add({'type': 'divider', 'text': 'Unread messages'});
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
        _loading = false;
      });
      _connectWebSocket();
    }
  }

  void _connectWebSocket() {
    if (_disposed) return;
    final url = ApiService.getClubChatWebSocketUrl(widget.clubId);
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    channel.ready.then((_) {
      if (_disposed || !identical(_channel, channel)) return;
      final wasReconnect = _reconnectAttempts > 0;
      _reconnectAttempts = 0;
      if (mounted) setState(() => _connected = true);
      if (wasReconnect) _syncMissedMessages();
    }).catchError((_) {
      // The stream's onError/onDone below schedules the retry.
    });
    channel.stream.listen((message) {
      if (mounted) {
        dynamic data;
        try {
          data = jsonDecode(message);
        } catch (_) {
          return;
        }
        if (data is! Map) return;
        if (data['action'] == 'error') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['detail']?.toString() ?? 'Message not sent')),
          );
          return;
        }
        setState(() {
          if (data['action'] == 'poll_vote') {
            final idx = _messages.indexWhere((m) => m['id'] == data['message_id']);
            if (idx != -1) {
              _messages[idx]['poll'] = data['poll'];
            }
          } else if (data['action'] == 'new') {
            _messages.add(data['message']);
            _scrollToBottom();
          } else if (data['action'] == 'edit') {
            final idx = _messages.indexWhere((m) => m['id'] == data['message']['id']);
            if (idx != -1) {
              _messages[idx] = data['message'];
            }
          } else if (data['action'] == 'delete_for_everyone') {
            final idx = _messages.indexWhere((m) => m['id'] == data['message_id']);
            if (idx != -1) {
              _messages[idx]['is_deleted'] = true;
              _messages[idx]['content'] = "This message was deleted";
              _messages[idx]['attachment_url'] = null;
              _messages[idx]['attachment_type'] = null;
              _messages[idx]['poll'] = null;
            }
          } else {
            // legacy fallback
            if (!data.containsKey('action')) {
              _messages.add(data);
              _scrollToBottom();
            }
          }
        });
      }
    }, onError: (_) {
      // onDone follows and handles the reconnect.
    }, onDone: () => _handleSocketClosed(channel));
  }

  void _handleSocketClosed(WebSocketChannel channel) {
    if (_disposed || !identical(_channel, channel)) return;
    if (mounted) setState(() => _connected = false);
    // 1008 = the server refused us (e.g. removed from the club): don't retry.
    if (channel.closeCode == 1008) return;
    final delay = Duration(seconds: [2, 4, 8, 16, 30][_reconnectAttempts.clamp(0, 4)]);
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connectWebSocket);
  }

  /// After a reconnect, fetch recent history and add anything we missed.
  Future<void> _syncMissedMessages() async {
    final history = await ApiService.getClubChatHistory(widget.clubId);
    if (!mounted) return;
    final known = _messages.map((m) => m['id']).whereType<int>().toSet();
    final missed = history
        .cast<Map<String, dynamic>>()
        .reversed
        .where((m) => m['id'] is int && !known.contains(m['id']))
        .toList();
    if (missed.isEmpty) return;
    setState(() => _messages.addAll(missed));
    _scrollToBottom();
  }


  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (!_connected || _channel == null) {
      // Keep the text so it isn't lost while we reconnect.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconnecting to chat... try again in a moment')),
      );
      return;
    }
    if (_channel != null) {
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
      backgroundColor: _ChatPalette.of(context).sheet,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.image, color: _ChatPalette.of(context).accent),
                title: Text('Upload Image', style: TextStyle(color: _ChatPalette.of(context).sheetText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAttachment(fp.FileType.image);
                },
              ),
              ListTile(
                leading: Icon(Icons.insert_drive_file, color: _ChatPalette.of(context).accent),
                title: Text('Upload Document', style: TextStyle(color: _ChatPalette.of(context).sheetText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAttachment(fp.FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
                },
              ),
              ListTile(
                leading: Icon(Icons.emoji_emotions, color: _ChatPalette.of(context).accent),
                title: Text('Send Sticker', style: TextStyle(color: _ChatPalette.of(context).sheetText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showStickerPicker();
                },
              ),
              ListTile(
                leading: Icon(Icons.poll_rounded, color: _ChatPalette.of(context).accent),
                title: Text('Create Poll', style: TextStyle(color: _ChatPalette.of(context).sheetText)),
                onTap: () {
                  Navigator.pop(ctx);
                  _createPoll();
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
      backgroundColor: _ChatPalette.of(context).sheet,
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
                  child: CachedNetworkImage(imageUrl: predefinedStickers[index]),
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

  Future<void> _createPoll() async {
    final poll = await showPollComposer(context, submitLabel: 'Send Poll');
    if (poll == null || _channel == null) return;
    _channel!.sink.add(jsonEncode({'content': '', 'poll': poll.toJson()}));
  }

  Future<void> _votePoll(Map<String, dynamic> msg, int optionIndex) async {
    final userId = _currentUserId;
    final messageId = msg['id'];
    final poll = msg['poll'];
    if (userId == null || messageId is! int || poll is! Map) return;

    final previous = Map<String, dynamic>.from(poll['votes'] as Map? ?? {});
    if (previous[userId.toString()] == optionIndex) return;

    // Show the vote right away; the server broadcast keeps everyone in sync.
    setState(() {
      poll['votes'] = {...previous, userId.toString(): optionIndex};
    });
    final updated = await ApiService.voteClubChatPoll(widget.clubId, messageId, optionIndex);
    if (!mounted) return;
    if (updated == null) {
      setState(() => poll['votes'] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record your vote')),
      );
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

  void _showMessageOptions(Map<String, dynamic> msg) {
    if (_currentUserId == null) return;
    
    final isMe = msg['user_id'] == _currentUserId;
    if (!isMe) return; // For now, only show options for own messages
    
    final dt = ZynkDateUtils.parseUtc(msg['created_at']);
    final bool within5Mins = dt != null && DateTime.now().difference(dt).inMinutes <= 5;
    final bool isDeleted = msg['is_deleted'] == true;
    final bool isPoll = msg['poll'] != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: _ChatPalette.of(context).sheet,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              if (within5Mins && !isDeleted && !isPoll)
                ListTile(
                  leading: Icon(Icons.edit, color: _ChatPalette.of(context).accent),
                  title: Text('Edit', style: TextStyle(color: _ChatPalette.of(context).sheetText)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(msg);
                  },
                ),
              if (within5Mins && !isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text('Delete for everyone', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ApiService.deleteClubChatMessage(widget.clubId, msg['id']);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete, color: _ChatPalette.of(context).sheetMuted),
                title: Text('Delete for me', style: TextStyle(color: _ChatPalette.of(context).sheetMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  ApiService.deleteClubChatMessage(widget.clubId, msg['id']);
                  setState(() {
                    _messages.removeWhere((m) => m['id'] == msg['id']);
                  });
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _showEditDialog(Map<String, dynamic> msg) {
    final editController = TextEditingController(text: msg['content'] == 'This message was deleted' ? '' : msg['content']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _ChatPalette.of(context).sheet,
        title: Text('Edit Message', style: TextStyle(color: _ChatPalette.of(context).sheetText)),
        content: TextField(
          controller: editController,
          style: TextStyle(color: _ChatPalette.of(context).sheetText),
          decoration: const InputDecoration(
            hintText: 'New message...',
            hintStyle: TextStyle(color: ZynkColors.darkMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: ZynkColors.darkMuted)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: ZynkColors.gold)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _ChatPalette.of(context).sheetMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ZynkColors.gold),
            onPressed: () {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty) {
                ApiService.editClubChatMessage(widget.clubId, msg['id'], newContent);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      )
    );
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
        if (!_connected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ZynkColors.gold),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connecting to chat...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            // reverse: true removed for normal scrolling
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
                        child: Text(msg['text'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                      Expanded(child: Divider(color: ZynkColors.darkMuted.withValues(alpha: 0.3))),
                    ],
                  ),
                );
              }
              final isMe = _currentUserId != null && msg['user_id'] == _currentUserId;
              final palette = _ChatPalette.of(context);
              final name = msg['user_name'] ?? 'User';
              final avatar = msg['user_avatar'] ?? 'https://api.dicebear.com/7.x/avataaars/png?seed=$name';
              final content = msg['content'] ?? '';
              
              final role = msg['user_role'] ?? 'member';
              
              final dt = ZynkDateUtils.parseUtc(msg['created_at']);
              final timeStr = dt != null ? DateFormat('h:mm a').format(dt) : '';
              
              final isDeleted = msg['is_deleted'] == true;
              final isEdited = msg['is_edited'] == true && !isDeleted;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      GestureDetector(
                        onTap: () {
                          if (msg['user_id'] != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: msg['user_id'])));
                          }
                        },
                        child: CircleAvatar(radius: 14, backgroundImage: CachedNetworkImageProvider(avatar)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: GestureDetector(
                        onLongPress: () => _showMessageOptions(msg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? ZynkColors.gold : palette.bubble,
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
                                    Text(name, style: TextStyle(color: isMe ? Colors.black54 : palette.bubbleMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: role == 'admin' ? (isMe ? Colors.black12 : ZynkColors.gold.withValues(alpha: 0.2)) : (isMe ? Colors.white10 : palette.chip),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(role.toUpperCase(), style: TextStyle(color: role == 'admin' ? (isMe ? Colors.black87 : palette.adminChipText) : (isMe ? Colors.black54 : palette.chipText), fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                              if (msg['poll'] is Map && !isDeleted)
                                ChatPollCard(
                                  poll: Map<String, dynamic>.from(msg['poll'] as Map),
                                  currentUserId: _currentUserId,
                                  isMine: isMe,
                                  onVote: (index) => _votePoll(msg, index),
                                )
                              else if (content.isNotEmpty)
                                Text(
                                  content, 
                                  style: TextStyle(
                                    color: isMe ? Colors.black87 : palette.bubbleText,
                                    fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                                  )
                                ),
                              if (msg['attachment_url'] != null) ...[
                                 const SizedBox(height: 8),
                                 if (msg['attachment_type'] == 'image' || msg['attachment_type'] == 'sticker' || msg['attachment_type'] == 'gif')
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: msg['attachment_url'])));
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(imageUrl: msg['attachment_url'], height: 150, fit: BoxFit.cover),
                                      ),
                                    )
                                 else
                                    GestureDetector(
                                      onTap: () => launchSafeUrl(msg['attachment_url']?.toString()),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.insert_drive_file, color: isMe ? Colors.black54 : palette.bubbleMuted, size: 20),
                                            const SizedBox(width: 8),
                                            Text('View Document', style: TextStyle(color: isMe ? Colors.black87 : palette.bubbleText)),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isEdited)
                                    Text('(Edited) ', style: TextStyle(color: isMe ? Colors.black45 : palette.bubbleMuted, fontSize: 10, fontStyle: FontStyle.italic)),
                                  Text(timeStr, style: TextStyle(color: isMe ? Colors.black54 : palette.bubbleMuted, fontSize: 10)),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _showMessageOptions(msg),
                                      child: const Icon(Icons.more_horiz, size: 14, color: Colors.black54),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (msg['user_id'] != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: msg['user_id'])));
                          }
                        },
                        child: CircleAvatar(radius: 14, backgroundImage: CachedNetworkImageProvider(avatar)),
                      ),
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
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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

/// A poll inside a chat bubble. Tap an option to vote; tap another to change
/// the vote. Colors follow the bubble (gold for your own messages).
class ChatPollCard extends StatelessWidget {
  final Map<String, dynamic> poll;
  final int? currentUserId;
  final bool isMine;
  final ValueChanged<int> onVote;

  const ChatPollCard({
    super.key,
    required this.poll,
    required this.currentUserId,
    required this.isMine,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final question = poll['question']?.toString() ?? '';
    final options = (poll['options'] as List?)?.map((o) => o.toString()).toList() ?? const <String>[];
    final votes = (poll['votes'] as Map?) ?? const {};
    final total = votes.length;
    final myVote = currentUserId == null ? null : votes[currentUserId.toString()];

    final palette = _ChatPalette.of(context);
    final textColor = isMine ? Colors.black87 : palette.bubbleText;
    final mutedColor = isMine ? Colors.black54 : palette.bubbleMuted;
    final fillColor = isMine ? Colors.black.withValues(alpha: 0.12) : ZynkColors.gold.withValues(alpha: 0.25);
    final trackColor = isMine ? Colors.black.withValues(alpha: 0.06) : palette.pollTrack;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.poll_rounded, size: 16, color: mutedColor),
              const SizedBox(width: 4),
              Text('POLL', style: TextStyle(color: mutedColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ],
          ),
          const SizedBox(height: 4),
          Text(question, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          for (var i = 0; i < options.length; i++)
            _option(
              text: options[i],
              count: votes.values.where((v) => v == i).length,
              total: total,
              selected: myVote == i,
              textColor: textColor,
              mutedColor: mutedColor,
              fillColor: fillColor,
              trackColor: trackColor,
              onTap: () => onVote(i),
            ),
          Text(
            total == 1 ? '1 vote' : '$total votes',
            style: TextStyle(color: mutedColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _option({
    required String text,
    required int count,
    required int total,
    required bool selected,
    required Color textColor,
    required Color mutedColor,
    required Color fillColor,
    required Color trackColor,
    required VoidCallback onTap,
  }) {
    final fraction = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: trackColor,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: ColoredBox(color: fillColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: selected ? textColor : mutedColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (total > 0)
                      Text(
                        '${(fraction * 100).round()}%',
                        style: TextStyle(color: mutedColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chat colours. Dark theme keeps the original values exactly; light theme
/// gets matching light surfaces so other people's bubbles and the menus no
/// longer render as dark blocks on a light screen. Your own bubbles stay gold.
class _ChatPalette {
  _ChatPalette.of(BuildContext context)
      : dark = Theme.of(context).brightness == Brightness.dark;

  final bool dark;

  // Bottom sheets and the edit dialog
  Color get sheet => dark ? ZynkColors.darkSurface : ZynkColors.lightSurface;
  Color get sheetText => dark ? Colors.white : ZynkColors.lightText;
  Color get sheetMuted => dark ? Colors.white70 : ZynkColors.lightMuted;
  // Brand lime is too faint on white, so light theme uses a deeper olive.
  Color get accent => dark ? ZynkColors.gold : const Color(0xFF6B7417);

  // Other people's message bubbles
  Color get bubble => dark ? ZynkColors.darkSurface2 : ZynkColors.lightElevated;
  Color get bubbleText => dark ? ZynkColors.offWhite : ZynkColors.lightText;
  Color get bubbleMuted => dark ? ZynkColors.darkMuted : ZynkColors.lightMuted;
  Color get chip => dark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
  Color get chipText => dark ? Colors.white70 : ZynkColors.lightMuted;
  Color get adminChipText => dark ? ZynkColors.gold : const Color(0xFF6B7417);
  Color get pollTrack =>
      dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
}
