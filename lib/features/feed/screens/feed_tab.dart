import 'package:zynkup/features/clubs/screens/all_clubs_screen.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'package:url_launcher/url_launcher.dart';

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
    if (!mounted) { return; }
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
      ZToast.showSuccess(
        context,
        'Post published',
        subtitle: 'Your update is now live on campus.',
      );
      _load();
    }
  }

  void _showComments(Map<String, dynamic> post) {
    if (!ApiService.hasToken) {
      showLoginPrompt(context, message: 'Join the campus to comment on posts.');
      return;
    }
    final postId = post['id'] as int?;
    if (postId == null) { return; }
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
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                leading: const Icon(
                  Icons.flag_outlined,
                  color: ZynkColors.error,
                ),
                title: const Text(
                  'Report Bad Content',
                  style: TextStyle(
                    color: ZynkColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (!ApiService.hasToken) {
                    showLoginPrompt(
                      context,
                      message: 'Sign in to report unsafe content.',
                    );
                    return;
                  }
                  final postId = post['id'] as int?;
                  if (postId != null) {
                    final success = await ApiService.reportFeedPost(postId);
                    if (success) {
                      ZToast.showSuccess(context, 'Reported successfully.');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to report post.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              if (_currentUserId != null &&
                  post['author_id']?.toString() ==
                      _currentUserId.toString()) ...[
                 Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  leading:  Icon(
                    Icons.edit_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  title:  Text(
                    'Edit Post',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
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
                        initialImageUrl: post['image_url'] ?? post['imageUrl'],
                        initialBannerUrl: post['banner_url'] ?? post['bannerUrl'],
                        initialLinkUrl: post['link_url'],
                        initialLinkTitle: post['link_title'],
                        initialLinkType: post['link_type'],
                      ),
                    );
                    if (result != null) { _load(); }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: ZynkColors.error,
                  ),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(
                      color: ZynkColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: isDark ? ZynkColors.darkSurface : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ZynkRadius.xl),
                          side: BorderSide(
                            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                          ),
                        ),
                        title: Text(
                          'Delete Post?',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to delete this post? This action cannot be undone.',
                          style: TextStyle(
                            color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: ZynkColors.error,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ZynkRadius.md),
                              ),
                            ),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;

                    final success = await ApiService.deleteFeedPost(post['id']);
                    if (success) {
                      ZToast.showSuccess(context, 'Post deleted');
                      _load();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1000;
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

  List<dynamic> get _trendingEvents {
    if (_events.isEmpty) return [];
    final now = DateTime.now();

    // 1. Filter active or upcoming events
    final active = _events.where((e) {
      if (e is! Map) return true;
      final dateStr = e['date'];
      if (dateStr == null) return true;
      final dt = DateTime.tryParse(dateStr.toString());
      if (dt == null) return true;
      return dt.isAfter(now.subtract(const Duration(hours: 12)));
    }).toList();

    final pool = active.isNotEmpty ? List<dynamic>.from(active) : List<dynamic>.from(_events);

    // 2. Sort by registration / attendee count descending
    pool.sort((a, b) {
      final countA = (a is Map)
          ? ((a['attendee_count'] as int?) ??
              ((a['registered_users'] as List?)?.length) ?? 0)
          : 0;
      final countB = (b is Map)
          ? ((b['attendee_count'] as int?) ??
              ((b['registered_users'] as List?)?.length) ?? 0)
          : 0;

      if (countB != countA) {
        return countB.compareTo(countA);
      }

      final dtA = DateTime.tryParse((a is Map ? a['date'] : '')?.toString() ?? '') ?? now;
      final dtB = DateTime.tryParse((b is Map ? b['date'] : '')?.toString() ?? '') ?? now;
      return dtA.compareTo(dtB);
    });

    return pool.take(3).toList();
  }

  Widget _buildMainFeed() {
    final filteredPosts = _posts.where((post) {
      if (_filter == 'All Posts') { return true; }
      if (_filter == 'Clubs Only') { return post['club_id'] != null; }
      if (_filter == 'Media Only') {
        return (post['image_url'] != null &&
                post['image_url'].toString().isNotEmpty) ||
            (post['banner_url'] != null &&
                post['banner_url'].toString().isNotEmpty);
      }
      if (_filter == 'Text Only') {
        return (post['image_url'] == null ||
                post['image_url'].toString().isEmpty) &&
            (post['banner_url'] == null ||
                post['banner_url'].toString().isEmpty);
      }
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
                child:  Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campus Feed',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "What's buzzing on campus?",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 14,
                        ),
                      ),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: GestureDetector(
                    onTap: _createNewPost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundImage: CachedNetworkImageProvider(
                              'https://api.dicebear.com/7.x/avataaars/png?seed=You',
                            ),
                            backgroundColor: ZynkColors.darkSurface2,
                          ),
                          const SizedBox(width: 12),
                           Expanded(
                            child: Text(
                              "Share something with your campus...",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Post',
                              style: TextStyle(
                                color: ZynkColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filter,
                            dropdownColor: Theme.of(context).colorScheme.surface,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: ZynkColors.primary,
                              size: 18,
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            items:
                                [
                                      'All Posts',
                                      'Clubs Only',
                                      'Media Only',
                                      'Text Only',
                                    ]
                                    .map(
                                      (String value) =>
                                          DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(
                                              value,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                    )
                                    .toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setState(() => _filter = newValue);
                              }
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
                    children: List.generate(
                      3,
                      (index) => const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: ZSkeleton(
                          width: double.infinity,
                          height: 220,
                          borderRadius: 16,
                        ),
                      ),
                    ),
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
                            showLoginPrompt(
                              context,
                              message: 'Join the campus to like this post.',
                            );
                            return;
                          }
                          final postId = post['id'] as int?;
                          if (postId != null) {
                            final isLiked = post['is_liked'] == true;
                            setState(() {
                              post['is_liked'] = !isLiked;
                              post['likes'] =
                                  (post['likes'] ?? 0) + (isLiked ? -1 : 1);
                            });
                            await ApiService.likeFeedPost(postId);
                          }
                        },
                        onReply: () => _showComments(post),
                        onShare: () async {
                          final postId = post['id'];
                          final baseUrl = kIsWeb ? Uri.base.origin : 'https://zynkup-app.vercel.app';
                          final shareUrl = '$baseUrl/feed/$postId';
                          final snippet = (post['content'] ?? '').toString().trim();
                          final text = snippet.isNotEmpty
                              ? '$snippet\n\nCheck out this post on Zynkup:\n$shareUrl'
                              : 'Check out this post on Zynkup:\n$shareUrl';
                          try {
                            await Share.share(text);
                          } catch (_) {}
                        },
                        onMore: () => _showMoreOptions(post),
                        onReact: (emoji) async {
                          if (!ApiService.hasToken) {
                            showLoginPrompt(
                              context,
                              message: 'Join the campus to react.',
                            );
                            return;
                          }
                          final postId = post['id'] as int?;
                          if (postId == null) { return; }
                          final oldReaction = post['user_reaction'] as String?;
                          setState(() {
                            post['user_reaction'] = (oldReaction == emoji)
                                ? null
                                : emoji;
                            final reactions =
                                post['reactions'] as Map<String, dynamic>? ??
                                {};
                            if (oldReaction != null) {
                              reactions[oldReaction] =
                                  (reactions[oldReaction] as int? ?? 1) - 1;
                            }
                            if (oldReaction != emoji) {
                              reactions[emoji] =
                                  (reactions[emoji] as int? ?? 0) + 1;
                            }
                            post['reactions'] = reactions;
                          });
                          await ApiService.reactToFeedPost(postId, emoji);
                        },
                        onVote: (optionIndex) async {
                          if (!ApiService.hasToken) {
                            showLoginPrompt(
                              context,
                              message: 'Join the campus to vote.',
                            );
                            return;
                          }
                          final postId = post['id'] as int?;
                          if (postId == null) { return; }
                          final poll = post['poll'] as Map<String, dynamic>?;
                          if (poll == null) { return; }
                          final votes =
                              poll['votes'] as Map<String, dynamic>? ?? {};
                          final userIdStr = _currentUserId?.toString() ?? '0';
                          if (votes.containsKey(userIdStr)) { return; }
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
          // Mobile-only: trending events and communities below the feed
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 700) return const SizedBox.shrink();
                return _buildMobileDiscovery();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDiscovery() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 32),

          // ── Trending Events ─────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFF65A30D)
                    : ZynkColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Trending Events',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            Column(
              children: List.generate(
                3,
                (i) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: ZSkeleton(width: double.infinity, height: 64, borderRadius: 12),
                ),
              ),
            )
          else if (_events.isEmpty)
            Text(
              'No trending events right now.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            )
          else
            ..._trendingEvents.map((e) => _buildMiniEventCard(e)),

          const SizedBox(height: 28),

          // ── Active Clubs ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFF65A30D)
                        : ZynkColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Communities',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllClubsScreen()),
                  );
                },
                child: Text(
                  'Clubs →',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFF65A30D)
                        : ZynkColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            Column(
              children: List.generate(
                2,
                (i) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: ZSkeleton(width: double.infinity, height: 60, borderRadius: 12),
                ),
              ),
            )
          else if (_clubs.isEmpty)
            Text(
              'No communities found.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            )
          else
            ..._clubs.take(4).map((c) => _buildMiniClubCard(c)),
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
           Text(
            'Trending Events',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            Column(
              children: List.generate(
                3,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ZSkeleton(
                    width: double.infinity,
                    height: 72,
                    borderRadius: 12,
                  ),
                ),
              ),
            )
          else if (_events.isEmpty)
            const Text(
              'No upcoming events right now.',
              style: TextStyle(color: ZynkColors.darkMuted),
            )
          else
            ..._trendingEvents.map((e) => _buildMiniEventCard(e)),

          const SizedBox(height: 48),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                'Active Clubs',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllClubsScreen()),
                  );
                },
                child: const Text(
                  'Clubs →',
                  style: TextStyle(
                    color: ZynkColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            Column(
              children: List.generate(
                3,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ZSkeleton(
                    width: double.infinity,
                    height: 64,
                    borderRadius: 12,
                  ),
                ),
              ),
            )
          else if (_clubs.isEmpty)
            const Text(
              'No communities found.',
              style: TextStyle(color: ZynkColors.darkMuted),
            )
          else
            ..._clubs.take(4).map((c) => _buildMiniClubCard(c)),
        ],
      ),
    );
  }

  Widget _buildMiniEventCard(dynamic event) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailsScreen(event: Event.fromJson(event)),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                image: event['cover_url'] != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(event['cover_url']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: event['cover_url'] == null
                  ?  Icon(
                      Icons.event_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] ?? 'Unnamed Event',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final attendeeCount = (event['attendee_count'] as int?) ??
                          ((event['registered_users'] as List?)?.length) ?? 0;
                      return Row(
                        children: [
                          Text(
                            event['category'] ?? 'Event',
                            style: const TextStyle(
                              color: ZynkColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (attendeeCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: ZynkColors.warmAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, color: ZynkColors.warmAccent, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$attendeeCount registered',
                                    style: const TextStyle(
                                      color: ZynkColors.warmAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClubProfileScreen(
              clubId: club['id'].toString(),
              clubName: club['name']?.toString() ?? 'Club',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: ZynkColors.darkSurface2,
              backgroundImage: club['logo_url'] != null
                  ? CachedNetworkImageProvider(club['logo_url'])
                  : null,
              child: club['logo_url'] == null
                  ?  Icon(
                      Icons.groups_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club['name'] ?? 'Unnamed Club',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                   Text(
                    'Campus Club',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 12),
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
    if (dateTimeStr == null) { return 'some time ago'; }
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) { return '${diff.inDays}d ago'; }
      if (diff.inHours > 0) { return '${diff.inHours}h ago'; }
      if (diff.inMinutes > 0) { return '${diff.inMinutes}m ago'; }
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
    final String? linkUrl = post['link_url'];
    final String? linkTitle = post['link_title'];
    final String? linkType = post['link_type'];
    final int likes = post['likes'] ?? 0;
    final bool isLiked = post['is_liked'] == true;
    final String? userReaction = post['user_reaction'] as String?;
    final String timeStr = _timeAgo(post['created_at'] as String?);

    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ZynkRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                    builder: (context) =>
                        FullScreenImageViewer(imageUrl: bannerUrl),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(ZynkRadius.lg - 1),
                ),
                child: CachedNetworkImage(
                  imageUrl: bannerUrl,
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
                                const Icon(
                                  Icons.group_rounded,
                                  size: 12,
                                  color: ZynkColors.gold,
                                ),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (post['club_id'] != null)
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                IconButton(
                  icon:  Icon(
                    Icons.more_vert_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
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
                    builder: (context) =>
                        FullScreenImageViewer(imageUrl: imageUrl),
                  ),
                );
              },
              child: CachedNetworkImage(
                imageUrl: imageUrl,
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),

          // Embedded Link Card
          if (linkUrl != null && linkUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _EmbeddedLinkCard(
                linkUrl: linkUrl,
                linkTitle: linkTitle,
                linkType: linkType,
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
                    icon: isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor: isLiked
                        ? ZynkColors.orange
                        : ZynkColors.darkMuted,
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
                  child: const ActionIcon(
                    icon: Icons.share_rounded,
                    label: 'Share',
                  ),
                ),
              ],
            ),
          ),

          if (post['poll'] != null)
            PollWidget(
              poll: post['poll'] as Map<String, dynamic>,
              onVote: onVote,
            ),
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              optionText,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                            ),
                            if (totalVotes > 0)
                              Text(
                                '${(percent * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Text(
              '$totalVotes votes',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 11),
            ),
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

  const ReactionStrip({
    super.key,
    required this.reactions,
    this.userReaction,
    required this.onReact,
  });

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
              margin: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Text(
                    emoji,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? Colors.white : Colors.white54,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: isSelected
                            ? ZynkColors.primary
                            : ZynkColors.darkMuted,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _EmbeddedLinkCard extends StatelessWidget {
  final String linkUrl;
  final String? linkTitle;
  final String? linkType;

  const _EmbeddedLinkCard({
    required this.linkUrl,
    this.linkTitle,
    this.linkType,
  });

  String? _getYouTubeId(String url) {
    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  Future<void> _openLink(BuildContext context) async {
    try {
      final uri = Uri.parse(linkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link.')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lower = linkUrl.toLowerCase();
    final effectiveType = linkType ??
        (lower.contains('youtube.com') || lower.contains('youtu.be')
            ? 'youtube'
            : (lower.contains('instagram.com') || lower.contains('instagr.am')
                ? 'instagram'
                : 'general'));

    if (effectiveType == 'youtube') {
      final ytid = _getYouTubeId(linkUrl);
      final thumbUrl = ytid != null ? 'https://img.youtube.com/vi/$ytid/hqdefault.jpg' : null;

      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openLink(context),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbUrl != null)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CachedNetworkImage(
                      imageUrl: thumbUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const SizedBox.shrink(),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'YouTube',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (linkTitle != null && linkTitle!.isNotEmpty) ? linkTitle! : linkUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Watch',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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

    if (effectiveType == 'instagram') {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openLink(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF833AB4).withValues(alpha: 0.2),
                      const Color(0xFFFD1D1D).withValues(alpha: 0.2),
                      const Color(0xFFFCB045).withValues(alpha: 0.2),
                    ]
                  : [
                      const Color(0xFF833AB4).withValues(alpha: 0.08),
                      const Color(0xFFFD1D1D).withValues(alpha: 0.08),
                      const Color(0xFFFCB045).withValues(alpha: 0.08),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE1306C).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instagram Post',
                      style: TextStyle(
                        color: Color(0xFFE1306C),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (linkTitle != null && linkTitle!.isNotEmpty) ? linkTitle! : linkUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFFE1306C)),
            ],
          ),
        ),
      );
    }

    // General Web Link Card
    final uri = Uri.tryParse(linkUrl);
    final domain = uri?.host.isNotEmpty == true ? uri!.host : 'Website';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openLink(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? ZynkColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.language_rounded,
                size: 20,
                color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (linkTitle != null && linkTitle!.isNotEmpty) ? linkTitle! : domain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    linkUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: isDark ? ZynkColors.darkMuted : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
