// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/features/feed/screens/create_post_screen.dart';
import 'package:zynkup/features/feed/screens/post_comments_sheet.dart';
import 'package:zynkup/features/feed/screens/edit_post_sheet.dart';
import 'package:zynkup/core/widgets/login_prompt_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zynkup/features/clubs/screens/club_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynkup/core/widgets/zynk_skeleton.dart';
import 'package:zynkup/core/widgets/zynk_empty_state.dart';
import 'package:zynkup/core/widgets/zynk_toast.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/profile/screens/profile_screen.dart';
import 'package:zynkup/core/widgets/full_screen_image_viewer.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  bool _loading = true;
  List<dynamic> _posts = [];
  List<dynamic> _events = [];
  List<dynamic> _clubs = [];
  int? _currentUserId;
  String _filter = 'All Posts';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final user = ApiService.hasToken ? await ApiService.getCurrentUser() : null;
    
    final results = await Future.wait([
      ApiService.getFeed(),
      ApiService.getEvents(),
      ApiService.getClubs(),
    ]);

    if (mounted) {
      setState(() {
        _currentUserId = int.tryParse(user?['id']?.toString() ?? '');
        _posts = results[0];
        _events = results[1];
        _clubs = results[2];
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
      ZToast.showSuccess(context, 'Post published', subtitle: 'Your update is now live on campus.');
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
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: ZynkColors.darkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: ZynkColors.error),
                title: const Text(
                  'Report Bad Content',
                  style: TextStyle(color: ZynkColors.error, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (!ApiService.hasToken) {
                    showLoginPrompt(context, message: 'Sign in to report unsafe content.');
                    return;
                  }
                  final postId = post['id'] as int?;
                  if (postId != null) {
                    final success = await ApiService.reportFeedPost(postId);
                    if (success) {
                      ZToast.showSuccess(context, 'Reported successfully.');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to report post.'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
              if (_currentUserId != null && post['author_id']?.toString() == _currentUserId.toString()) ...[
                const Divider(color: ZynkColors.darkBorder),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: ZynkColors.offWhite),
                  title: const Text('Edit Post', style: TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final result = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EditPostSheet(postId: post['id'], initialContent: post['content'] ?? ''),
                    );
                    if (result != null) _load();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: ZynkColors.error),
                  title: const Text('Delete Post', style: TextStyle(color: ZynkColors.error, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final success = await ApiService.deleteFeedPost(post['id']);
                    if (success) {
                      ZToast.showSuccess(context, 'Post deleted');
                      _load();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete post')));
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
    final isDesktop = MediaQuery.of(context).size.width > 1000;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ZynkBackground(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildMainFeed()),
              if (isDesktop) ...[
                const SizedBox(width: 32),
                Expanded(flex: 3, child: _buildRightRail()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainFeed() {
    final filteredPosts = _posts.where((post) {
      if (_filter == 'All Posts') return true;
      if (_filter == 'Clubs Only') return post['club_id'] != null;
      if (_filter == 'Media Only') return (post['image_url'] != null && post['image_url'].toString().isNotEmpty) || (post['banner_url'] != null && post['banner_url'].toString().isNotEmpty);
      if (_filter == 'Text Only') return (post['image_url'] == null || post['image_url'].toString().isEmpty) && (post['banner_url'] == null || post['banner_url'].toString().isEmpty);
      return true;
    }).toList();

    return RefreshIndicator(
      color: ZynkColors.primary,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 32, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Campus Feed', style: TextStyle(color: ZynkColors.darkText, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      SizedBox(height: 8),
                      Text("What's buzzing on campus?", style: TextStyle(color: ZynkColors.darkMuted, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: GestureDetector(
                    onTap: _createNewPost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(color: ZynkColors.darkSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: ZynkColors.darkBorder)),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 18, backgroundImage: CachedNetworkImageProvider('https://api.dicebear.com/7.x/avataaars/png?seed=You'), backgroundColor: ZynkColors.darkSurface2),
                          const SizedBox(width: 12),
                          const Expanded(child: Text("Share something with your campus...", style: TextStyle(color: ZynkColors.darkMuted, fontSize: 15))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: ZynkColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Post', style: TextStyle(color: ZynkColors.primary, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: ZynkColors.darkSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: ZynkColors.darkBorder)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filter,
                            dropdownColor: ZynkColors.darkSurface,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: ZynkColors.primary, size: 18),
                            style: const TextStyle(color: ZynkColors.offWhite, fontSize: 13, fontWeight: FontWeight.w600),
                            items: ['All Posts', 'Clubs Only', 'Media Only', 'Text Only'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) setState(() => _filter = newValue);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    children: List.generate(3, (index) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: ZSkeleton(width: double.infinity, height: 220, borderRadius: 16),
                    )),
                  ),
                ),
              ),
            )
          else if (filteredPosts.isEmpty)
            SliverToBoxAdapter(
              child: ZEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Your campus is quiet',
                subtitle: 'Be the first to share something exciting.',
                actionLabel: 'Create a post',
                onAction: _createNewPost,
              ),
            )
          else
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      final post = filteredPosts[index] as Map<String, dynamic>;
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
                          await Share.share(text);
                        },
                        onMore: () => _showMoreOptions(post),
                        onReact: (emoji) async {
                          if (!ApiService.hasToken) {
                            showLoginPrompt(context, message: 'Join the campus to react.');
                            return;
                          }
                          final postId = post['id'] as int?;
                          if (postId == null) return;
                          final oldReaction = post['user_reaction'] as String?;
                          setState(() {
                            post['user_reaction'] = (oldReaction == emoji) ? null : emoji;
                            final reactions = post['reactions'] as Map<String, dynamic>? ?? {};
                            if (oldReaction != null) reactions[oldReaction] = (reactions[oldReaction] as int? ?? 1) - 1;
                            if (oldReaction != emoji) reactions[emoji] = (reactions[emoji] as int? ?? 0) + 1;
                            post['reactions'] = reactions;
                          });
                          await ApiService.reactToFeedPost(postId, emoji);
                        },
                        onVote: (optionIndex) async {
                          if (!ApiService.hasToken) {
                            showLoginPrompt(context, message: 'Join the campus to vote.');
                            return;
                          }
                          final postId = post['id'] as int?;
                          if (postId == null) return;
                          final poll = post['poll'] as Map<String, dynamic>?;
                          if (poll == null) return;
                          final votes = poll['votes'] as Map<String, dynamic>? ?? {};
                          final userIdStr = _currentUserId?.toString() ?? '0';
                          if (votes.containsKey(userIdStr)) return;
                          setState(() {
                            votes[userIdStr] = optionIndex;
                            poll['votes'] = votes;
                          });
                          await ApiService.votePoll(postId, optionIndex);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightRail() {
    return Container(
      padding: const EdgeInsets.only(top: 48, right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trending Events', style: TextStyle(color: ZynkColors.offWhite, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_loading)
            Column(children: List.generate(3, (index) => const Padding(padding: EdgeInsets.only(bottom: 12), child: ZSkeleton(width: double.infinity, height: 72, borderRadius: 12))))
          else if (_events.isEmpty)
            const Text('No upcoming events right now.', style: TextStyle(color: ZynkColors.darkMuted))
          else
            ..._events.take(3).map((e) => _buildMiniEventCard(e)),
            
          const SizedBox(height: 48),
          
          const Text('Active Communities', style: TextStyle(color: ZynkColors.offWhite, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_loading)
            Column(children: List.generate(3, (index) => const Padding(padding: EdgeInsets.only(bottom: 12), child: ZSkeleton(width: double.infinity, height: 64, borderRadius: 12))))
          else if (_clubs.isEmpty)
            const Text('No communities found.', style: TextStyle(color: ZynkColors.darkMuted))
          else
            ..._clubs.take(4).map((c) => _buildMiniClubCard(c)),
        ],
      ),
    );
  }

  Widget _buildMiniEventCard(dynamic event) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailsScreen(event: Event.fromJson(event))));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: ZynkColors.darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: ZynkColors.darkBorder)),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ZynkColors.darkSurface2,
                borderRadius: BorderRadius.circular(8),
                image: event['cover_url'] != null ? DecorationImage(image: CachedNetworkImageProvider(event['cover_url']), fit: BoxFit.cover) : null,
              ),
              child: event['cover_url'] == null ? const Icon(Icons.event_rounded, color: ZynkColors.darkMuted, size: 20) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event['title'] ?? 'Unnamed Event', style: const TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(event['category'] ?? 'Event', style: const TextStyle(color: ZynkColors.primary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniClubCard(dynamic club) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ClubProfileScreen(clubId: club['id'].toString(), clubName: club['name']?.toString() ?? 'Club')));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: ZynkColors.darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: ZynkColors.darkBorder)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: ZynkColors.darkSurface2,
              backgroundImage: club['logo_url'] != null ? CachedNetworkImageProvider(club['logo_url']) : null,
              child: club['logo_url'] == null ? const Icon(Icons.groups_rounded, color: ZynkColors.darkMuted, size: 20) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club['name'] ?? 'Unnamed Club', style: const TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  const Text('Campus Community', style: TextStyle(color: ZynkColors.darkMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
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
    final String? userReaction = post['user_reaction'] as String?;
    final String timeStr = _timeAgo(post['created_at'] as String?);

    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface,
        borderRadius: BorderRadius.circular(ZynkRadius.lg),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Attachment
          if (hasBanner)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenImageViewer(imageUrl: bannerUrl),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(ZynkRadius.lg - 1)),
                child: CachedNetworkImage(imageUrl: bannerUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
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
                    backgroundImage: CachedNetworkImageProvider(avatarUrl),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (post['club_id'] != null)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClubProfileScreen(
                                  clubId: post['club_id'].toString(),
                                  clubName: post['club_name'] ?? 'Club',
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.group_rounded, size: 12, color: ZynkColors.gold),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    post['club_name'] ?? 'Club',
                                    style: const TextStyle(
                                      color: ZynkColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: ZynkColors.darkMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (post['club_id'] != null)
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: ZynkColors.darkMuted,
                      fontSize: 12,
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
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenImageViewer(imageUrl: imageUrl),
                  ),
                );
              },
              child: CachedNetworkImage(imageUrl: imageUrl,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
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
            userReaction: userReaction,
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
  final String? userReaction;
  final Function(String) onReact;

  const ReactionStrip({super.key, required this.reactions, this.userReaction, required this.onReact});

  @override
  Widget build(BuildContext context) {
    final emojis = ['🔥', '🎉', '💯', '👀'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: emojis.map((emoji) {
          final count = reactions[emoji] as int? ?? 0;
          final isSelected = userReaction == emoji;
          return GestureDetector(
            onTap: () => onReact(emoji),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? ZynkColors.primary.withValues(alpha: 0.2) : ZynkColors.darkSurface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? ZynkColors.primary : ZynkColors.darkBorder),
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
