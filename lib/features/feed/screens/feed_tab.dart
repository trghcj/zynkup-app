import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/features/feed/screens/create_post_screen.dart';
import 'package:zynkup/features/feed/screens/post_comments_sheet.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  bool _loading = true;
  List<dynamic> _posts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await ApiService.getFeed();
    if (mounted) {
      setState(() {
        _posts = data;
        _loading = false;
      });
    }
  }

  Future<void> _createNewPost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (result == true) {
      _load();
    }
  }

  void _showComments(Map<String, dynamic> post) {
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
      ),
    );
  }

  void _showMoreOptions(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  Navigator.pop(context);
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
                  Navigator.pop(context);
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
                          'Stay updated with what\'s happening on campus.',
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
                                "Share a campus update...",
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
                          'No campus updates yet. Be the first to share one!',
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
                        return _FeedPostCard(
                          post: post,
                          onLike: () async {
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
                          onShare: () {
                            Clipboard.setData(ClipboardData(text: post['content'] ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
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
                          },
                          onMore: () => _showMoreOptions(post),
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

class _FeedPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onShare;
  final VoidCallback onMore;

  const _FeedPostCard({
    required this.post,
    required this.onLike,
    required this.onReply,
    required this.onShare,
    required this.onMore,
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
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(avatarUrl),
                  backgroundColor: ZynkColors.darkSurface2,
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
                  icon: const Icon(Icons.more_horiz_rounded, color: ZynkColors.darkMuted),
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
                  child: _ActionIcon(
                    icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    iconColor: isLiked ? ZynkColors.orange : ZynkColors.darkMuted,
                    label: '$likes',
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: onReply,
                  child: const _ActionIcon(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Reply',
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onShare,
                  child: const _ActionIcon(icon: Icons.share_rounded, label: 'Share'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _ActionIcon({
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
