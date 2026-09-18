import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/features/clubs/screens/club_profile_screen.dart';
import 'package:zynkup/features/clubs/screens/create_club_screen.dart';

class MyClubsScreen extends StatefulWidget {
  const MyClubsScreen({super.key});

  @override
  State<MyClubsScreen> createState() => _MyClubsScreenState();
}

class _MyClubsScreenState extends State<MyClubsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  List<dynamic> _createdClubs = [];
  List<dynamic> _joinedClubs = [];
  List<dynamic> _followingClubs = [];

  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Technical',
    'Cultural',
    'Sports',
    'Academic',
    'Social',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClubs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMyClubs();
      if (mounted) {
        setState(() {
          _createdClubs = res['created'] as List<dynamic>? ?? [];
          _joinedClubs = res['joined'] as List<dynamic>? ?? [];
          _followingClubs = res['following'] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _filterClubs(List<dynamic> list) {
    return list.where((c) {
      final club = c is Map<String, dynamic> ? c : <String, dynamic>{};
      final name = (club['name'] ?? '').toString().toLowerCase();
      final desc = (club['description'] ?? '').toString().toLowerCase();
      final cat = (club['category'] ?? '').toString().toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == 'All' ||
          cat == _selectedCategory.toLowerCase();

      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Clubs Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
            tooltip: 'Found New Club',
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateClubScreen()),
              );
              if (res == true) _loadClubs();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
          indicatorWeight: 3,
          labelColor: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          tabs: [
            Tab(text: 'Created (${_createdClubs.length})'),
            Tab(text: 'Joined (${_joinedClubs.length})'),
            Tab(text: 'Following (${_followingClubs.length})'),
          ],
        ),
      ),
      body: ZynkBackground(
        child: Column(
          children: [
            // Search and Category Filter Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search Bar
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search my clubs...',
                            hintStyle: TextStyle(
                              color: isDark ? ZynkColors.darkMuted : const Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Category Filter Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            icon: Icon(
                              Icons.filter_list_rounded,
                              size: 18,
                              color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                            ),
                            dropdownColor: isDark ? ZynkColors.darkSurface : Colors.white,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            items: _categories.map((cat) {
                              return DropdownMenuItem<String>(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tab Contents
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildClubList(
                          _filterClubs(_createdClubs),
                          emptyMessage: 'You haven\'t created any clubs yet.',
                          emptyActionText: 'Found a Club',
                          onEmptyAction: () async {
                            final res = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreateClubScreen()),
                            );
                            if (res == true) _loadClubs();
                          },
                        ),
                        _buildClubList(
                          _filterClubs(_joinedClubs),
                          emptyMessage: 'You haven\'t joined any clubs yet.',
                          emptyActionText: 'Explore Clubs',
                          onEmptyAction: () => Navigator.pop(context),
                        ),
                        _buildClubList(
                          _filterClubs(_followingClubs),
                          emptyMessage: 'You\'re not following any clubs yet.',
                          emptyActionText: 'Explore Clubs',
                          onEmptyAction: () => Navigator.pop(context),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubList(
    List<dynamic> clubs, {
    required String emptyMessage,
    required String emptyActionText,
    required VoidCallback onEmptyAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (clubs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark
                      ? ZynkColors.primary.withValues(alpha: 0.12)
                      : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_outlined,
                  size: 36,
                  color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onEmptyAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  emptyActionText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClubs,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        itemCount: clubs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final club = clubs[index] as Map<String, dynamic>;
          final name = club['name'] ?? 'Club';
          final desc = club['description'] ?? '';
          final logoUrl = club['logo_url'] ?? '';
          final category = club['category'] ?? 'General';
          final membersCount = club['member_count'] ?? 0;
          final followersCount = club['followers_count'] ?? 0;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClubProfileScreen(
                    clubId: club['id'].toString(),
                    clubName: name,
                    clubData: club,
                  ),
                ),
              );
              _loadClubs();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? ZynkColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF1F5F9),
                    backgroundImage: (logoUrl.isNotEmpty)
                        ? CachedNetworkImageProvider(logoUrl)
                        : null,
                    child: logoUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: TextStyle(
                              color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? ZynkColors.primary.withValues(alpha: 0.15)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category.toString().toUpperCase(),
                                style: TextStyle(
                                  color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 14,
                              color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$membersCount members',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 14,
                              color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$followersCount followers',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? ZynkColors.darkMuted : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
