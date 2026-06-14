import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';
import 'package:zynkup/features/feed/screens/feed_tab.dart';
import 'package:zynkup/features/feed/screens/create_post_screen.dart';
import 'package:zynkup/features/feed/screens/post_comments_sheet.dart';
import 'package:zynkup/features/profile/screens/profile_screen.dart';
import 'package:zynkup/features/clubs/widgets/club_chat_widget.dart';
import 'package:zynkup/core/widgets/login_prompt_sheet.dart';
import 'package:zynkup/core/widgets/full_screen_image_viewer.dart';
import 'package:zynkup/features/feed/screens/edit_post_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ClubProfileScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final Map<String, dynamic>? clubData;

  const ClubProfileScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.clubData,
  });

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _club;
  Map<String, dynamic>? _currentUser;
  bool _loading = false;
  bool _isMember = false;

  List<dynamic> _clubEvents = [];
  bool _loadingEvents = false;

  List<dynamic> _clubMembers = [];
  bool _loadingMembers = false;

  List<dynamic> _clubGallery = [];
  bool _loadingGallery = false;
  
  List<dynamic> _clubFeed = [];
  bool _loadingFeed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadCurrentUser();
    if (widget.clubData != null) {
      _club = widget.clubData;
      _isMember = widget.clubData?['is_member'] == true;
      _loadAllTabDetails();
    } else {
      _loadClub().then((_) {
        _loadAllTabDetails();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAllTabDetails() {
    _loadFeed();
    _loadEvents();
    _loadMembers();
    _loadGallery();
  }

  Future<void> _loadFeed() async {
    setState(() => _loadingFeed = true);
    try {
      final feed = await ApiService.getClubFeed(int.parse(widget.clubId));
      if (mounted) {
        setState(() {
          _clubFeed = feed;
          _loadingFeed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFeed = false);
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await ApiService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _loadClub() async {
    setState(() => _loading = true);
    try {
      final found = await ApiService.getClubById(int.parse(widget.clubId));
      if (mounted) {
        setState(() {
          _club = found;
          _isMember = found?['is_member'] == true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final events = await ApiService.getClubEvents(int.parse(widget.clubId));
      if (mounted) {
        setState(() {
          _clubEvents = events;
          _loadingEvents = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final members = await ApiService.getClubMembers(int.parse(widget.clubId));
      if (mounted) {
        setState(() {
          _clubMembers = members;
          _loadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadGallery() async {
    setState(() => _loadingGallery = true);
    try {
      final files = await ApiService.getClubGallery(int.parse(widget.clubId));
      if (mounted) {
        setState(() {
          _clubGallery = files;
          _loadingGallery = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGallery = false);
    }
  }

  Future<void> _toggleMembership() async {
    if (!ApiService.hasToken) {
      showLoginPrompt(context, message: 'Sign in to join this club.');
      return;
    }
    final result = await ApiService.joinClub(int.parse(widget.clubId));
    if (result != null && result['success'] == true) {
      final didJoin = result['joined'] == true;
      // Reload club details to get fresh member count and is_member status
      await _loadClub();
      _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(didJoin ? 'Joined ${widget.clubName}!' : 'Left ${widget.clubName}'),
            backgroundColor: didJoin ? ZynkColors.primary : ZynkColors.darkMuted,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update membership. Please try again.'),
            backgroundColor: ZynkColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteClub() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Club?'),
        content: const Text('This action cannot be undone. All events, members, and posts will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: ZynkColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final success = await ApiService.deleteClub(int.parse(widget.clubId));
    if (success && mounted) {
      Navigator.of(context).pop(); // Close club profile
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Club deleted successfully.'),
          backgroundColor: ZynkColors.darkSurface2,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete club. Please try again.'),
          backgroundColor: ZynkColors.error,
        ),
      );
    }
  }

  bool get _canHostEvent {
    if (_club == null || _currentUser == null) return false;
    if (_club!['creator_id']?.toString() == _currentUser!['id']?.toString()) return true;
    final record = _clubMembers.firstWhere(
      (m) => m['user_id']?.toString() == _currentUser!['id']?.toString(),
      orElse: () => null,
    );
    if (record != null) {
      final role = record['role']?.toString().toLowerCase() ?? 'member';
      return role != 'member';
    }
    return false;
  }

  bool get _canUploadGallery {
    if (_club == null || _currentUser == null) return false;
    if (_club!['creator_id']?.toString() == _currentUser!['id']?.toString()) return true;
    final record = _clubMembers.firstWhere(
      (m) => m['user_id']?.toString() == _currentUser!['id']?.toString(),
      orElse: () => null,
    );
    if (record != null) {
      final role = record['role']?.toString().toLowerCase() ?? 'member';
      return role != 'member';
    }
    return false;
  }

  Future<void> _uploadGalleryImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: ZynkColors.gold),
            ),
            SizedBox(width: 16),
            Text('Uploading photo to gallery...'),
          ],
        ),
        backgroundColor: ZynkColors.darkSurface2,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final bytes = await file.readAsBytes();
      final filename = file.name.split('/').last.split('\\').last;

      final result = await ApiService.uploadClubGallery(
        int.parse(widget.clubId),
        bytes,
        filename,
      );

      messenger.clearSnackBars();

      if (result != null) {
        _loadGallery();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: ZynkColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image.'),
              backgroundColor: ZynkColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      messenger.clearSnackBars();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ZynkColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showRoleAssignmentDialog(int userId, String name, String currentRole) async {
    final controller = TextEditingController(text: currentRole);
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ZynkColors.darkSurface2,
          title: Text('Assign Role for $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Give this member a role in the club. You can type anything (e.g. Co-Founder, Treasurer, Organizer) or select a preset.',
                style: TextStyle(color: ZynkColors.darkMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: ZynkColors.offWhite),
                decoration: const InputDecoration(
                  labelText: 'Role Name',
                  hintText: 'e.g. Moderator',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ActionChip(
                    label: const Text('Admin'),
                    onPressed: () => controller.text = 'admin',
                  ),
                  ActionChip(
                    label: const Text('Moderator'),
                    onPressed: () => controller.text = 'moderator',
                  ),
                  ActionChip(
                    label: const Text('Member'),
                    onPressed: () => controller.text = 'member',
                  ),
                ],
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: ZynkColors.darkMuted)),
            ),
            TextButton(
              onPressed: () async {
                final newRole = controller.text.trim();
                if (newRole.isNotEmpty) {
                  Navigator.pop(context);
                  final success = await ApiService.updateClubMemberRole(
                    int.parse(widget.clubId),
                    userId,
                    newRole,
                  );
                  if (success) {
                    _loadMembers();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Successfully assigned "$newRole" role to $name.'),
                          backgroundColor: ZynkColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Failed to update member role.'),
                          backgroundColor: ZynkColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: ZynkColors.gold, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeMember(int userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZynkColors.darkSurface2,
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $name from the club?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: ZynkColors.darkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: ZynkColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.loadToken();
        final res = await http.delete(
          Uri.parse("${ApiService.baseUrl}/clubs/${widget.clubId}/members/$userId"),
          headers: {
            "Authorization": "Bearer ${await FlutterSecureStorage().read(key: 'token')}",
          },
        );
        if (res.statusCode == 200) {
          _loadMembers();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$name removed from club'), backgroundColor: ZynkColors.success),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to remove member'), backgroundColor: ZynkColors.error),
            );
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerImage = (_club != null && _club!['banner_url'] != null && _club!['banner_url'].isNotEmpty)
        ? _club!['banner_url']
        : 'https://picsum.photos/seed/${widget.clubId}/800/400';

    final logoImage = (_club != null && _club!['logo_url'] != null && _club!['logo_url'].isNotEmpty)
        ? _club!['logo_url']
        : 'https://picsum.photos/seed/${widget.clubId}/200/200';

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Scaffold(
          backgroundColor: ZynkColors.darkBg,
          body: ZynkBackground(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: ZynkColors.gold))
                : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: 280,
                      pinned: true,
                      backgroundColor: ZynkColors.darkBg,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          widget.clubName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: ZynkColors.offWhite,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                          ),
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(imageUrl: bannerImage,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    ZynkColors.darkBg.withValues(alpha: 0.8),
                                    ZynkColors.darkBg,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        if (_club != null && _currentUser != null && _club!['creator_id']?.toString() == _currentUser!['id']?.toString())
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: ZynkColors.darkText),
                            onSelected: (val) {
                              if (val == 'delete') _deleteClub();
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete Club', style: TextStyle(color: ZynkColors.error)),
                              ),
                            ],
                          ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: ZynkColors.darkSurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: ZynkColors.gold, width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 32,
                                    backgroundImage: CachedNetworkImageProvider(logoImage),
                                    backgroundColor: ZynkColors.darkSurface2,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: ZynkColors.gold.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(ZynkRadius.pill),
                                          border: Border.all(color: ZynkColors.gold.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          (_club?['category'] ?? 'general').toString().toUpperCase(),
                                          style: const TextStyle(
                                            color: ZynkColors.gold,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Official Student Club',
                                        style: TextStyle(
                                          color: ZynkColors.darkMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_club == null || _currentUser == null || (_club!['creator_id']?.toString() != _currentUser!['id']?.toString()))
                                  SizedBox(
                                    width: 110,
                                    child: ZynkButton(
                                      height: 36,
                                      label: _isMember ? 'Joined' : 'Join',
                                      outlined: _isMember,
                                      icon: _isMember ? Icons.check_rounded : Icons.add_rounded,
                                      onTap: _toggleMembership,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _club != null && _club!['description'] != null
                                  ? _club!['description']
                                  : 'The official ${widget.clubName} of MAIT. We build, create, and innovate together.',
                              style: const TextStyle(color: ZynkColors.offWhite, fontSize: 14, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.people_alt_rounded, color: ZynkColors.gold, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  '${_club?['member_count'] ?? 0} Members',
                                  style: const TextStyle(color: ZynkColors.gold, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          indicatorColor: ZynkColors.gold,
                          labelColor: ZynkColors.gold,
                          unselectedLabelColor: ZynkColors.darkMuted,
                          dividerColor: Colors.transparent,
                          isScrollable: true,
                          tabs: const [
                            Tab(text: 'Feed'),
                            Tab(text: 'Chat'),
                            Tab(text: 'Events'),
                            Tab(text: 'Members'),
                            Tab(text: 'Gallery'),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFeedTab(),
                    ClubChatWidget(clubId: int.parse(widget.clubId)),
                    _buildEventsTab(),
                    _buildMembersTab(),
                    _buildGalleryTab(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

  void _showMoreOptions(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bool isAuthor = _currentUser?['id'] != null && post['author_id']?.toString() == _currentUser?['id']?.toString();
        final bool isCreator = _club != null && _currentUser != null && _club!['creator_id']?.toString() == _currentUser!['id']?.toString();
        
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
              if (isAuthor) ...[
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
                    if (result != null) _loadFeed();
                  },
                ),
              ],
              if (isAuthor || isCreator) ...[
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: ZynkColors.error),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: ZynkColors.error, fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: ZynkColors.darkSurface2,
                        title: const Text('Delete Post', style: TextStyle(color: ZynkColors.error)),
                        content: const Text('Are you sure you want to delete this post?', style: TextStyle(color: ZynkColors.offWhite)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel', style: TextStyle(color: ZynkColors.darkMuted)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete', style: TextStyle(color: ZynkColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final success = await ApiService.deleteFeedPost(post['id']);
                      if (success) _loadFeed();
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

  Widget _buildFeedTab() {
    if (_loadingFeed) {
      return const Center(child: CircularProgressIndicator(color: ZynkColors.gold));
    }
    
    return RefreshIndicator(
      color: ZynkColors.gold,
      onRefresh: _loadFeed,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_isMember)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatePostScreen(
                          clubId: int.parse(widget.clubId),
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadFeed();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: ZynkColors.darkSurface2,
                      borderRadius: BorderRadius.circular(ZynkRadius.lg),
                      border: Border.all(color: ZynkColors.darkBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: CachedNetworkImageProvider(_currentUser?['avatar_url'] ?? 'https://api.dicebear.com/7.x/avataaars/png?seed=User'),
                        ),
                        const SizedBox(width: 12),
                        const Text('Share something with the club...', style: TextStyle(color: ZynkColors.darkMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_clubFeed.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No posts yet.', style: TextStyle(color: ZynkColors.darkMuted)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final post = _clubFeed[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FeedPostCard(
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
                      onReply: () {
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
                      },
                      onMore: () => _showMoreOptions(post),
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

                      onReact: (emoji) async {
                        final postId = post['id'] as int?;
                        if (postId != null) {
                          await ApiService.reactToFeedPost(postId, emoji);
                          _loadFeed();
                        }
                      },
                      onVote: (optionIndex) async {
                        final postId = post['id'] as int?;
                        if (postId != null) {
                          await ApiService.votePoll(postId, optionIndex);
                          _loadFeed();
                        }
                      },
                    ),
                  );
                },
                childCount: _clubFeed.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    if (_loadingEvents) {
      return const Center(child: CircularProgressIndicator(color: ZynkColors.gold));
    }
    
    return RefreshIndicator(
      color: ZynkColors.gold,
      onRefresh: _loadEvents,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_canHostEvent)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: ZynkButton(
                  label: 'Host an Event',
                  icon: Icons.add_rounded,
                  onTap: () async {
                    final res = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateEventScreen(clubId: int.parse(widget.clubId)),
                      ),
                    );
                    if (res == true) {
                      _loadEvents();
                    }
                  },
                ),
              ),
            ),
          if (_clubEvents.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded, size: 48, color: ZynkColors.darkMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'Your next campus moment starts here',
                        style: TextStyle(color: ZynkColors.darkMuted, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = _clubEvents[index];
                  return _ClubEventCard(
                    event: event,
                    onTap: () {
                      final eventObj = Event.fromJson(event);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => EventDetailsScreen(event: eventObj),
                      );
                    },
                  );
                },
                childCount: _clubEvents.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    if (_loadingMembers) {
      return const Center(child: CircularProgressIndicator(color: ZynkColors.gold));
    }
    
    final isCreator = _club != null && _club!['creator_id']?.toString() == _currentUser?['id']?.toString();
    
    return RefreshIndicator(
      color: ZynkColors.gold,
      onRefresh: _loadMembers,
      child: _clubMembers.isEmpty
          ? const Center(child: Text('No members in this club.', style: TextStyle(color: ZynkColors.darkMuted)))
          : ListView.builder(
              padding: const EdgeInsets.only(top: 16, bottom: 100),
              itemCount: _clubMembers.length,
              itemBuilder: (context, index) {
                final m = _clubMembers[index] as Map<String, dynamic>;
                final name = m['name'] ?? 'Student';
                final avatar = m['avatar_url'];
                final role = m['role']?.toString().toUpperCase() ?? 'MEMBER';
                final userId = m['user_id'] as int;
                
                final avatarUrl = (avatar != null && avatar.isNotEmpty)
                    ? avatar
                    : 'https://api.dicebear.com/7.x/avataaars/png?seed=$name';
                    
                final isSelfCreator = userId.toString() == _club!['creator_id']?.toString();

                return ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: userId),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(avatarUrl),
                    backgroundColor: ZynkColors.darkSurface2,
                  ),
                  title: Text(name, style: const TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    isSelfCreator ? 'CLUB CREATOR' : 'ROLE: $role',
                    style: TextStyle(
                      color: isSelfCreator ? ZynkColors.gold : ZynkColors.darkMuted,
                      fontWeight: isSelfCreator ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isCreator && !isSelfCreator
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shield_outlined, color: ZynkColors.gold),
                              tooltip: 'Assign custom role',
                              onPressed: () => _showRoleAssignmentDialog(userId, name, m['role'] ?? 'member'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_remove_rounded, color: ZynkColors.error),
                              tooltip: 'Remove from club',
                              onPressed: () => _removeMember(userId, name),
                            ),
                          ],
                        )
                      : isSelfCreator
                          ? const Icon(Icons.workspace_premium_rounded, color: ZynkColors.gold)
                          : null,
                );
              },
            ),
    );
  }

  Widget _buildGalleryTab() {
    if (_loadingGallery) {
      return const Center(child: CircularProgressIndicator(color: ZynkColors.gold));
    }
    
    final canUpload = _canUploadGallery;
    final totalCount = _clubGallery.length + (canUpload ? 1 : 0);
    
    return RefreshIndicator(
      color: ZynkColors.gold,
      onRefresh: _loadGallery,
      child: totalCount == 0
          ? const Center(
              child: Text(
                'No photos in gallery yet.',
                style: TextStyle(color: ZynkColors.darkMuted),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: totalCount,
              itemBuilder: (context, index) {
                if (canUpload && index == 0) {
                  return GestureDetector(
                    onTap: _uploadGalleryImage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: ZynkColors.darkSurface2,
                        borderRadius: BorderRadius.circular(ZynkRadius.md),
                        border: Border.all(color: ZynkColors.gold.withValues(alpha: 0.4), style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_rounded, color: ZynkColors.gold, size: 32),
                          const SizedBox(height: 8),
                          const Text(
                            'Upload Photo',
                            style: TextStyle(color: ZynkColors.gold, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                final fileIndex = canUpload ? index - 1 : index;
                final file = _clubGallery[fileIndex] as Map<String, dynamic>;
                final url = file['url']?.toString();
                if (url != null && url.isNotEmpty) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageViewer(imageUrl: url),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(ZynkRadius.md),
                          child: CachedNetworkImage(imageUrl: url,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: ZynkColors.darkSurface2,
                                        borderRadius: BorderRadius.circular(ZynkRadius.md),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.broken_image_rounded, color: ZynkColors.darkMuted),
                                      ),
                                    ),
                                    if (canUpload)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () async {
                                            final success = await ApiService.deleteClubGalleryImage(int.parse(widget.clubId), fileIndex);
                                            if (success) _loadGallery();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                          ),
                        ),
                      ),
                      if (canUpload)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () async {
                              final success = await ApiService.deleteClubGalleryImage(int.parse(widget.clubId), fileIndex);
                              if (success) _loadGallery();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                            ),
                          ),
                        ),
                    ],
                  );
                }

                // Fallback: base64 encoded data
                final data = file['data']?.toString();
                if (data != null && data.isNotEmpty) {
                  try {
                    final bytes = base64Decode(data);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenImageViewer(imageBytes: bytes),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(ZynkRadius.md),
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: ZynkColors.darkSurface2,
                                        borderRadius: BorderRadius.circular(ZynkRadius.md),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.broken_image_rounded, color: ZynkColors.darkMuted),
                                      ),
                                    ),
                                    if (canUpload)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () async {
                                            final success = await ApiService.deleteClubGalleryImage(int.parse(widget.clubId), fileIndex);
                                            if (success) _loadGallery();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ),
                          ),
                        ),
                        if (canUpload)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () async {
                                final success = await ApiService.deleteClubGalleryImage(int.parse(widget.clubId), fileIndex);
                                if (success) _loadGallery();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                              ),
                            ),
                          ),
                      ],
                    );
                  } catch (_) {}
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: ZynkColors.darkSurface2,
                        borderRadius: BorderRadius.circular(ZynkRadius.md),
                      ),
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, color: ZynkColors.darkMuted),
                      ),
                    ),
                    if (canUpload)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () async {
                            final success = await ApiService.deleteClubGalleryImage(int.parse(widget.clubId), fileIndex);
                            if (success) _loadGallery();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _ClubEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const _ClubEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String title = event['title'] ?? 'Event';
    final String venue = event['venue'] ?? 'TBD';
    final String dateStr = event['date'] ?? '';
    final String category = event['category'] ?? 'tech';
    final List<dynamic>? imageUrls = event['image_urls'] as List<dynamic>?;
    final String? image = (imageUrls != null && imageUrls.isNotEmpty) ? imageUrls.first.toString() : null;

    DateTime? dt;
    try {
      dt = DateTime.parse(dateStr).toLocal();
    } catch (_) {}

    final dateFormatted = dt != null ? DateFormat('MMM d, yyyy • hh:mm a').format(dt) : 'Date TBD';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: ZynkGradients.cardSurface,
          borderRadius: BorderRadius.circular(ZynkRadius.lg),
          border: Border.all(color: ZynkColors.darkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null && image.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(ZynkRadius.lg - 1)),
                child: CachedNetworkImage(imageUrl: image,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: ZynkGradients.forCategory(category),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(ZynkRadius.lg - 1)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CategoryBadge(category),
                      const Spacer(),
                      Text(
                        dateFormatted,
                        style: TextStyle(
                          color: ZynkColors.darkMuted.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZynkColors.offWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: ZynkColors.gold, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ZynkColors.darkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: ZynkColors.darkBg.withValues(alpha: 0.95),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}