import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/features/feed/screens/create_post_screen.dart';
import 'package:zynkup/features/feed/screens/post_comments_sheet.dart';
import 'package:zynkup/features/feed/screens/edit_post_sheet.dart';
import 'package:zynkup/core/widgets/login_prompt_sheet.dart';
import 'package:zynkup/features/profile/screens/profile_screen.dart';
import 'package:share_plus/share_plus.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  bool _loading = true;
  List<dynamic> _posts = [];
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final user = ApiService.hasToken ? await ApiService.getCurrentUser() : null;
    final data = await ApiService.getFeed();
    if (mounted) {
      setState(() {
        _currentUserId = int.tryParse(user?['id']?.toString() ?? '');
        _posts = data;
        _loading = false;
      });
    }
  }

  Future<void> _createNewPost() async {
    if (!ApiService.hasToken) {
      showLoginPrompt(context, message: 'Join the campus to share a post.');
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (result == true) {
      _load();
    }
  }

  void _showComments(Map<String, dynamic> post) {
    if (!ApiService.hasToken) {
      showLoginPrompt(context, message: 'Join the campus to comment on posts.');
      return;
    }
    final postId = post['id'] as int?;
    if (postId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostCommentsSheet(
        postId: postId,
        authorName: post['author_name'] ?? 'Anonymous',
        authorAvatar: post['author_avatar'],
        postContent: post['content'] ?? '',
        authorId: post['author_id'],
      ),
    );
  }

  void _showMoreOptions(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: ZynkColors.darkSurface2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: ZynkColors.darkBorder),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ZynkColors.darkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: ZynkColors.gold),
                title: const Text(
                  'Watch Full Feed / View Discussion',
                  style: TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showComments(post);
                },
              ),
              const Divider(color: ZynkColors.darkBorder),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: ZynkColors.error),
                title: const Text(
                  'Report Bad Content',
                  style: TextStyle(color: ZynkColors.error, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheetContext);
                  if (!ApiService.hasToken) {
                    showLoginPrompt(context, message: 'Sign in to report unsafe content.');
                    return;
                  }
                  final postId = post['id'] as int?;
                  if (postId != null) {
                    final success = await ApiService.reportFeedPost(postId);
                    if (success) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: ZynkColors.error),
                              SizedBox(width: 12),
                              Text('Post reported successfully.'),
                            ],
                          ),
                          backgroundColor: ZynkColors.darkSurface,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Failed to report post.'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
              if (_currentUserId != null &&
                  post['author_id']?.toString() == _currentUserId.toString()) ...[
                const Divider(color: ZynkColors.darkBorder),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: ZynkColors.offWhite),
                  title: const Text(
                    'Edit Post',
                    style: TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final result = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EditPostSheet(
                        postId: post['id'],
                        initialContent: post['content'] ?? '',
                      ),
                    );
                    if (result != null) _load();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: ZynkColors.error),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: ZynkColors.error, fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(sheetContext);
                    final success = await ApiService.deleteFeedPost(post['id']);
                    if (success) {
                      _load();
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Failed to delete post')),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ZynkBackground(
          child: RefreshIndicator(
            color: ZynkColors.gold,
            onRefresh: _load,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus Feed',
                          style: TextStyle(
                            color: ZynkColors.offWhite,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'What\'s buzzing on campus?',
                          style: TextStyle(color: ZynkColors.darkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: GestureDetector(
                      onTap: _createNewPost,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: ZynkGradients.cardSurface,
                          borderRadius: BorderRadius.circular(ZynkRadius.lg),
                          border: Border.all(color: ZynkColors.darkBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: const NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=You'),
                              backgroundColor: ZynkColors.darkSurface2,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "What's buzzing right now?",
                                style: TextStyle(
                                  color: ZynkColors.darkMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: ZynkColors.gold,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: ZynkColors.gold),
                      ),
                    ),
                  )
                else if (_posts.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'Your campus story starts here - be the first.',
                          style: TextStyle(color: ZynkColors.darkMuted),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = _posts[index] as Map<String, dynamic>;
                        return FeedPostCard(
                          post: post,
                          onLike: () async {
                            if (!ApiService.hasToken) {
                              showLoginPrompt(context, message: 'Join the campus to like this post.');
                              return;
                            }
                            final postId = post['id'] as int?;
                            if (postId != null) {
                              final isLiked = post['is_liked'] == true;
                              setState(() {
                                post['is_liked'] = !isLiked;
                                post['likes'] = (post['likes'] ?? 0) + (isLiked ? -1 : 1);
                              });
                              await ApiService.likeFeedPost(postId);
                            }
                          },
                          onReply: () => _showComments(post),
                          onShare: () async {
                            final text = post['content'] ?? '';
                            if (text.isEmpty) return;
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await Share.share(text);
                            } catch (_) {
                              await Clipboard.setData(ClipboardData(text: text));
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, color: ZynkColors.gold),
                                      SizedBox(width: 12),
                                      Text('Copied post text to clipboard!'),
                                    ],
                                  ),
                                  backgroundColor: ZynkColors.darkSurface2,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: ZynkColors.gold.withValues(alpha: 0.3)),
                                  ),
                                ),
                              );
                            }
                          },
                          onMore: () => _showMoreOptions(post),
                          onReact: (emoji) async {
                            if (!ApiService.hasToken) {
                              showLoginPrompt(context, message: 'Join the campus to react.');
                              return;
                            }
                            final postId = post['id'] as int?;
                            if (postId != null) {
                              await ApiService.reactToFeedPost(postId, emoji);
                              _load();
                            }
                          },
                          onVote: (optionIndex) async {
                            if (!ApiService.hasToken) {
                              showLoginPrompt(context, message: 'Join the campus to vote.');
                              return;
                            }
                            final postId = post['id'] as int?;
                            if (postId != null) {
                              await ApiService.votePoll(postId, optionIndex);
                              _load();
                            }
                          },
                        );
                      },
                      childCount: _posts.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewPost,
        backgroundColor: ZynkColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
      ),
    );
  }
}

class FeedPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final Function(String) onReact;
  final Function(int) onVote;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onReply,
    required this.onShare,
    required this.onMore,
    required this.onReact,
    required this.onVote,
  });

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
    final String authorName = post['author_name'] ?? 'Anonymous';
    final String? authorAvatar = post['author_avatar'];
    final String avatarUrl = (authorAvatar != null && authorAvatar.isNotEmpty)
        ? authorAvatar
        : 'https://api.dicebear.com/7.x/avataaars/png?seed=$authorName';
    final String content = post['content'] ?? '';
    final String? imageUrl = post['image_url'];
    final String? bannerUrl = post['banner_url'];
    final int likes = post['likes'] ?? 0;
    final bool isLiked = post['is_liked'] == true;
    final String timeStr = _timeAgo(post['created_at'] as String?);

    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        gradient: ZynkGradients.cardSurface,
        borderRadius: BorderRadius.circular(ZynkRadius.lg),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Attachment
          if (hasBanner)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(ZynkRadius.lg - 1)),
              child: Image.network(
                bannerUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          // Author Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final uid = post['author_id'];
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
                    radius: 18,
                    backgroundImage: NetworkImage(avatarUrl),
                    backgroundColor: ZynkColors.darkSurface2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          color: ZynkColors.offWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: ZynkColors.darkMuted.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: ZynkColors.darkMuted),
                  onPressed: onMore,
                ),
              ],
            ),
          ),

          // Image Content
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),

          // Text Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: const TextStyle(
                color: ZynkColors.offWhite,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),

          // Action Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onLike,
                  child: ActionIcon(
                    icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    iconColor: isLiked ? ZynkColors.orange : ZynkColors.darkMuted,
                    label: '$likes',
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: onReply,
                  child: const ActionIcon(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Reply',
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onShare,
                  child: const ActionIcon(icon: Icons.share_rounded, label: 'Share'),
                ),
              ],
            ),
          ),

          if (post['poll'] != null)
            PollWidget(poll: post['poll'] as Map<String, dynamic>, onVote: onVote),
          ReactionStrip(
            reactions: post['reactions'] as Map<String, dynamic>? ?? {},
            onReact: onReact,
          ),
        ],
      ),
    );
  }
}

class PollWidget extends StatelessWidget {
  final Map<String, dynamic> poll;
  final Function(int) onVote;

  const PollWidget({super.key, required this.poll, required this.onVote});

  @override
  Widget build(BuildContext context) {
    final question = poll['question'] as String? ?? '';
    final options = (poll['options'] as List<dynamic>?) ?? [];
    final votes = poll['votes'] as Map<String, dynamic>? ?? {};
    final totalVotes = votes.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ZynkColors.darkSurface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZynkColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: const TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...List.generate(options.length, (index) {
              final optionText = options[index].toString();
              final voteCount = votes.values.where((v) => v == index).length;
              final percent = totalVotes > 0 ? voteCount / totalVotes : 0.0;

              return GestureDetector(
                onTap: () => onVote(index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: ZynkColors.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZynkColors.darkBorder),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: percent,
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: ZynkColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(optionText, style: const TextStyle(color: ZynkColors.offWhite, fontSize: 13)),
                            if (totalVotes > 0)
                              Text('${(percent * 100).toStringAsFixed(0)}%', style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Text('$totalVotes votes', style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class ReactionStrip extends StatelessWidget {
  final Map<String, dynamic> reactions;
  final Function(String) onReact;

  const ReactionStrip({super.key, required this.reactions, required this.onReact});

  @override
  Widget build(BuildContext context) {
    final emojis = ['🔥', '🎉', '💯', '👀'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: emojis.map((emoji) {
          final count = reactions[emoji] as int? ?? 0;
          return GestureDetector(
            onTap: () => onReact(emoji),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: count > 0 ? ZynkColors.primary.withValues(alpha: 0.2) : ZynkColors.darkSurface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: count > 0 ? ZynkColors.primary : ZynkColors.darkBorder),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text('$count', style: const TextStyle(color: ZynkColors.offWhite, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const ActionIcon({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? ZynkColors.darkMuted, size: 20),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: ZynkColors.darkMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}