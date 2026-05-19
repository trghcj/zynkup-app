import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/core/api/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: ZynkColors.gold),
                  ),
                )
              else if (_posts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No campus updates yet.',
                      style: TextStyle(color: ZynkColors.darkMuted),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _FeedPostCard(
                      post: _posts[index] as Map<String, dynamic>,
                      onLike: () async {
                        final postId = _posts[index]['id'] as int?;
                        if (postId != null) {
                          await ApiService.getFeed(); // Refresh or call like
                        }
                      },
                    ),
                    childCount: _posts.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;

  const _FeedPostCard({
    required this.post,
    required this.onLike,
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
    final int likes = post['likes'] ?? 0;
    final String timeStr = _timeAgo(post['created_at'] as String?);

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
                  onPressed: () {},
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
                  child: _ActionIcon(icon: Icons.favorite_border_rounded, label: '$likes'),
                ),
                const SizedBox(width: 24),
                const _ActionIcon(icon: Icons.chat_bubble_outline_rounded, label: 'Reply'),
                const Spacer(),
                const _ActionIcon(icon: Icons.share_rounded, label: 'Share'),
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
  const _ActionIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ZynkColors.darkMuted, size: 20),
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
