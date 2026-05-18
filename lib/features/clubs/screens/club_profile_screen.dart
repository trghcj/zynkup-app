import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';

class ClubProfileScreen extends StatefulWidget {
  final String clubId;
  final String clubName;

  const ClubProfileScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isMember = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleMembership() {
    setState(() {
      _isMember = !_isMember;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMember ? 'Joined ${widget.clubName}!' : 'Left ${widget.clubName}'),
        backgroundColor: _isMember ? ZynkColors.primary : ZynkColors.darkMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      body: ZynkBackground(
        child: NestedScrollView(
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
                        'https://picsum.photos/seed/${widget.clubId}/800/400',
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
                      Text(
                        'The official ${widget.clubName} of MAIT. We build, create, and innovate together.',
                        style: const TextStyle(color: ZynkColors.offWhite, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, color: ZynkColors.gold, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            '1.2k Members',
                            style: TextStyle(color: ZynkColors.gold, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 24),
                          const Icon(Icons.workspace_premium_rounded, color: ZynkColors.orange, size: 18),
                          const SizedBox(width: 8),
                          const Text(
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
