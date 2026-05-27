import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';

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
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _loadEvents();
    _loadMembers();
    _loadGallery();
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
    final success = await ApiService.joinClub(int.parse(widget.clubId));
    if (success) {
      // Reload club details to get fresh member count and is_member status
      await _loadClub();
      _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isMember ? 'Joined ${widget.clubName}!' : 'Left ${widget.clubName}'),
            backgroundColor: _isMember ? ZynkColors.primary : ZynkColors.darkMuted,
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

  bool get _canHostEvent {
    if (_club == null || _currentUser == null) return false;
    if (_club!['creator_id'] == _currentUser!['id']) return true;
    final record = _clubMembers.firstWhere(
      (m) => m['user_id'] == _currentUser!['id'],
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
    if (_club!['creator_id'] == _currentUser!['id']) return true;
    final record = _clubMembers.firstWhere(
      (m) => m['user_id'] == _currentUser!['id'],
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
                            Image.network(
                              bannerImage,
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
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Center(
                            child: ZynkButton(
                              label: _isMember ? 'Joined' : 'Join Club',
                              outlined: _isMember,
                              icon: _isMember ? Icons.check_rounded : Icons.add_rounded,
                              onTap: _toggleMembership,
                            ),
                          ),
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
                                    backgroundImage: NetworkImage(logoImage),
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
                          tabs: const [
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
                        'No events hosted yet.',
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
    
    final isCreator = _club != null && _club!['creator_id'] == _currentUser?['id'];
    
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
                    
                final isSelfCreator = userId == _club!['creator_id'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
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
                      ? IconButton(
                          icon: const Icon(Icons.shield_outlined, color: ZynkColors.gold),
                          tooltip: 'Assign custom role',
                          onPressed: () => _showRoleAssignmentDialog(userId, name, m['role'] ?? 'member'),
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
                final url = file['url'] ?? '';
                
                return ClipRRect(
                  borderRadius: BorderRadius.circular(ZynkRadius.md),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: ZynkColors.darkSurface2,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, color: ZynkColors.darkMuted),
                      ),
                    ),
                  ),
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
                child: Image.network(
                  image,
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