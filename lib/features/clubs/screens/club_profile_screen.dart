import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';

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
  bool _loading = false;
  bool _isMember = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.clubData != null) {
      _club = widget.clubData;
    } else {
      _loadClub();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClub() async {
    setState(() => _loading = true);
    try {
      final allClubs = await ApiService.getClubs();
      final found = allClubs.firstWhere(
        (c) => c['id'].toString() == widget.clubId,
        orElse: () => null,
      );
      if (mounted) {
        setState(() {
          _club = found;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleMembership() async {
    final success = await ApiService.joinClub(int.parse(widget.clubId));
    if (success) {
      setState(() {
        _isMember = !_isMember;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isMember ? 'Joined ${widget.clubName}!' : 'Left ${widget.clubName}'),
            backgroundColor: _isMember ? ZynkColors.primary : ZynkColors.darkMuted,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update membership. Please try again.'),
            backgroundColor: ZynkColors.error,
          ),
        );
      }
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

    return Scaffold(
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
                            // Custom logo avatar stacked with the profile header details
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
                            const Row(
                              children: [
                                Icon(Icons.people_alt_rounded, color: ZynkColors.gold, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '1.2k Members',
                                  style: TextStyle(color: ZynkColors.gold, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 24),
                                Icon(Icons.workspace_premium_rounded, color: ZynkColors.orange, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Rank #2',
                                  style: TextStyle(color: ZynkColors.orange, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildEventsTab() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 100),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: ZynkGradients.cardSurface,
              borderRadius: BorderRadius.circular(ZynkRadius.lg),
              border: Border.all(color: ZynkColors.darkBorder),
            ),
            child: const Center(child: Text('Club Event Placeholder', style: TextStyle(color: ZynkColors.darkMuted))),
          ),
        );
      },
    );
  }

  Widget _buildMembersTab() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16),
      itemCount: 15,
      itemBuilder: (context, index) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=${widget.clubId}_$index'),
            backgroundColor: ZynkColors.darkSurface2,
          ),
          title: Text('Student $index', style: const TextStyle(color: ZynkColors.offWhite)),
          subtitle: Text('Member since 2024', style: const TextStyle(color: ZynkColors.darkMuted)),
          trailing: index == 0 ? const Icon(Icons.admin_panel_settings, color: ZynkColors.gold) : null,
        );
      },
    );
  }

  Widget _buildGalleryTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(ZynkRadius.md),
          child: Image.network(
            'https://picsum.photos/seed/${widget.clubId}_gallery_$index/400/400',
            fit: BoxFit.cover,
          ),
        );
      },
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
