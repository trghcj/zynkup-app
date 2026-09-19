import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/login_prompt_sheet.dart';
import 'package:zynkup/core/services/bookmark_service.dart';
import 'package:zynkup/features/feed/screens/feed_tab.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final Map<String, dynamic>? initialPost;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<dynamic> _comments = [];
  bool _loading = true;
  bool _submittingComment = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPost != null) {
      _post = Map<String, dynamic>.from(widget.initialPost!);
    }
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = _post == null);
    try {
      final results = await Future.wait([
        ApiService.getFeedPostById(widget.postId),
        ApiService.getFeedComments(widget.postId),
      ]);

      if (mounted) {
        setState(() {
          if (results[0] != null) {
            _post = results[0] as Map<String, dynamic>;
          }
          _comments = (results[1] as List<dynamic>?) ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!ApiService.hasToken) {
      showLoginPrompt(context, message: 'Join the campus to comment.');
      return;
    }

    setState(() => _submittingComment = true);
    try {
      final newComment = await ApiService.createFeedComment(widget.postId, text);
      _commentController.clear();
      setState(() {
        _comments.add(newComment);
        _submittingComment = false;
      });
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  Future<void> _sharePost() async {
    final baseUrl = kIsWeb ? Uri.base.origin : 'https://zynkup-app.vercel.app';
    final shareUrl = '$baseUrl/feed/${widget.postId}';
    final snippet = (_post?['content'] ?? '').toString().trim();
    final text = snippet.isNotEmpty
        ? '$snippet\n\nCheck out this post on Zynkup:\n$shareUrl'
        : 'Check out this post on Zynkup:\n$shareUrl';
    try {
      await Share.share(text);
    } catch (_) {}
  }

  Future<void> _handleBookmark() async {
    if (_post == null) return;
    final bookmarked = await BookmarkService.togglePostBookmark(_post!);
    if (!mounted) return;
    BookmarkService.showBookmarkToast(
      context,
      isBookmarked: bookmarked,
      itemType: 'Post',
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _sharePost,
            tooltip: 'Share post',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Post not found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This post may have been removed or is no longer available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            FeedPostCard(
                              post: _post!,
                              isBookmarked: BookmarkService.isPostBookmarkedSync(widget.postId),
                              onBookmark: _handleBookmark,
                              onLike: () async {
                                if (!ApiService.hasToken) {
                                  showLoginPrompt(context, message: 'Join the campus to like this post.');
                                  return;
                                }
                                final isLiked = _post!['is_liked'] == true;
                                setState(() {
                                  _post!['is_liked'] = !isLiked;
                                  _post!['likes'] = (_post!['likes'] ?? 0) + (isLiked ? -1 : 1);
                                });
                                await ApiService.likeFeedPost(widget.postId);
                              },
                              onReply: () {},
                              onShare: _sharePost,
                              onMore: () {},
                              onReact: (emoji) async {
                                if (!ApiService.hasToken) {
                                  showLoginPrompt(context, message: 'Join the campus to react.');
                                  return;
                                }
                                final oldReaction = _post!['user_reaction'] as String?;
                                setState(() {
                                  _post!['user_reaction'] = (oldReaction == emoji) ? null : emoji;
                                });
                                await ApiService.reactToFeedPost(widget.postId, emoji);
                              },
                              onVote: (optionIndex) async {
                                if (!ApiService.hasToken) {
                                  showLoginPrompt(context, message: 'Join the campus to vote.');
                                  return;
                                }
                                await ApiService.votePoll(widget.postId, optionIndex);
                                _load();
                              },
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'Comments (${_comments.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (_comments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text(
                                    'No comments yet. Start the conversation!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _comments.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  indent: 64,
                                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                                ),
                                itemBuilder: (context, index) {
                                  final comment = _comments[index];
                                  final authorName = comment['author_name'] ?? 'Student';
                                  final authorAvatar = comment['author_avatar'] as String?;
                                  final content = comment['content'] ?? '';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFE2E8F0),
                                          backgroundImage: (authorAvatar != null && authorAvatar.isNotEmpty)
                                              ? CachedNetworkImageProvider(authorAvatar)
                                              : null,
                                          child: (authorAvatar == null || authorAvatar.isEmpty)
                                              ? Text(
                                                  authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                authorName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                content,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  height: 1.35,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _submittingComment
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded, color: ZynkColors.primary),
                            onPressed: _submittingComment ? null : _submitComment,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
