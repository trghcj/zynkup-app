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
    final url = ApiService.getClubChatWebSocketUrl(widget.clubId);
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen((message) {
      if (mounted) {
        final data = jsonDecode(message);
        if (data is Map && data['action'] == 'error') {
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
    }, onError: (err) {
      // Handle error
    });
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
    _channel?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
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
              ListTile(
                leading: const Icon(Icons.poll_rounded, color: ZynkColors.gold),
                title: const Text('Create Poll', style: TextStyle(color: Colors.white)),
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
      backgroundColor: ZynkColors.darkSurface,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              if (within5Mins && !isDeleted && !isPoll)
                ListTile(
                  leading: const Icon(Icons.edit, color: ZynkColors.gold),
                  title: const Text('Edit', style: TextStyle(color: Colors.white)),
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
                leading: const Icon(Icons.delete, color: Colors.white70),
                title: const Text('Delete for me', style: TextStyle(color: Colors.white70)),
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
        backgroundColor: ZynkColors.darkSurface,
        title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          style: const TextStyle(color: Colors.white),
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
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
                                    color: isMe ? Colors.black87 : ZynkColors.offWhite,
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
                                            Icon(Icons.insert_drive_file, color: isMe ? Colors.black54 : Colors.white70, size: 20),
                                            const SizedBox(width: 8),
                                            Text('View Document', style: TextStyle(color: isMe ? Colors.black87 : Colors.white)),
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
                                    Text('(Edited) ', style: TextStyle(color: isMe ? Colors.black45 : ZynkColors.darkMuted, fontSize: 10, fontStyle: FontStyle.italic)),
                                  Text(timeStr, style: TextStyle(color: isMe ? Colors.black54 : ZynkColors.darkMuted, fontSize: 10)),
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

    final textColor = isMine ? Colors.black87 : ZynkColors.offWhite;
    final mutedColor = isMine ? Colors.black54 : ZynkColors.darkMuted;
    final fillColor = isMine ? Colors.black.withValues(alpha: 0.12) : ZynkColors.gold.withValues(alpha: 0.25);
    final trackColor = isMine ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.06);

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
