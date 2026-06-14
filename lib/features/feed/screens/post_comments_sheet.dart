import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/profile/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostCommentsSheet extends StatefulWidget {
  final int postId;
  final String authorName;
  final String? authorAvatar;
  final String postContent;
  final int? authorId;

  const PostCommentsSheet({
    super.key,
    required this.postId,
    required this.authorName,
    this.authorAvatar,
    required this.postContent,
    this.authorId,
  });

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _submitting = false;
  List<dynamic> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getFeedComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = data;
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final newComment = await ApiService.createFeedComment(widget.postId, text);
      if (mounted) {
        setState(() {
          _comments.add(newComment);
          _commentController.clear();
          _submitting = false;
        });
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: ZynkColors.error),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit comment.'),
            backgroundColor: ZynkColors.error,
          ),
        );
      }
    }
  }

  String _timeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return 'some time ago';
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return 'some time ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final primaryAvatar = (widget.authorAvatar != null && widget.authorAvatar!.isNotEmpty)
        ? widget.authorAvatar!
        : 'https://api.dicebear.com/7.x/avataaars/png?seed=${widget.authorName}';

    return Container(
      padding: EdgeInsets.only(bottom: keyboardPadding),
      decoration: BoxDecoration(
        color: ZynkColors.darkBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ZynkColors.darkMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Discussion Title
            const Text(
              'Discussion Thread',
              style: TextStyle(
                color: ZynkColors.offWhite,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: ZynkColors.darkBorder, height: 1),

            // Original Post Summary
            Container(
              color: ZynkColors.darkSurface.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.authorId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: widget.authorId),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: CachedNetworkImageProvider(primaryAvatar),
                      backgroundColor: ZynkColors.darkSurface2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.authorName,
                          style: const TextStyle(
                            color: ZynkColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.postContent,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ZynkColors.offWhite.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: ZynkColors.darkBorder, height: 1),

            // Comments List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: ZynkColors.gold),
                    )
                  : _comments.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: ZynkColors.darkMuted,
                                size: 36,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No replies yet.',
                                style: TextStyle(
                                  color: ZynkColors.offWhite,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Be the first to start the discussion!',
                                style: TextStyle(
                                  color: ZynkColors.darkMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final c = _comments[index] as Map<String, dynamic>;
                            final name = c['author_name'] ?? 'Student';
                            final avatar = c['author_avatar'];
                            final content = c['content'] ?? '';
                            final time = _timeAgo(c['created_at'] as String?);
                            final avatarUrl = (avatar != null && avatar.isNotEmpty)
                                ? avatar
                                : 'https://api.dicebear.com/7.x/avataaars/png?seed=$name';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      final uid = c['author_id'];
                                      if (uid != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProfileScreen(userId: uid as int),
                                          ),
                                        );
                                      }
                                    },
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundImage: CachedNetworkImageProvider(avatarUrl),
                                      backgroundColor: ZynkColors.darkSurface2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: ZynkColors.darkSurface2
                                            .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: ZynkColors.darkBorder
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  color: ZynkColors.offWhite,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                time,
                                                style: const TextStyle(
                                                  color: ZynkColors.darkMuted,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            content,
                                            style: const TextStyle(
                                              color: ZynkColors.offWhite,
                                              fontSize: 13,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Message Composer Area
            const Divider(color: ZynkColors.darkBorder, height: 1),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              color: ZynkColors.darkSurface,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _commentController,
                      style: const TextStyle(color: ZynkColors.offWhite, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Add a reply...',
                        hintStyle: TextStyle(
                          color: ZynkColors.darkMuted.withValues(alpha: 0.6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: ZynkColors.darkSurface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: ZynkColors.darkBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: ZynkColors.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: ZynkColors.gold, width: 1.5),
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onFieldSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _submitting ? null : _submitComment,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: ZynkGradients.buttonPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
