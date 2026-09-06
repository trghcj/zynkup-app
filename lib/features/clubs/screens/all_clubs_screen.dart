import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/login_prompt_sheet.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/core/widgets/zynk_skeleton.dart';
import 'package:zynkup/core/widgets/zynk_empty_state.dart';
import 'package:zynkup/features/clubs/screens/club_profile_screen.dart';
import 'package:zynkup/features/clubs/screens/create_club_screen.dart';

class AllClubsScreen extends StatefulWidget {
  const AllClubsScreen({super.key});

  @override
  State<AllClubsScreen> createState() => _AllClubsScreenState();
}

class _AllClubsScreenState extends State<AllClubsScreen> {
  bool _loading = true;
  List<dynamic> _clubs = [];
  String _searchQuery = '';
  String _categoryFilter = 'All Clubs';
  final TextEditingController _searchController = TextEditingController();

  static const _clubCategories = [
    'All Clubs',
    'tech',
    'cultural',
    'sports',
    'workshop',
    'seminar',
    'general',
  ];

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    setState(() => _loading = true);
    final data = await ApiService.getClubs();
    if (!mounted) {
      return;
    }
    setState(() {
      _clubs = data;
      _loading = false;
    });
  }

  void _createClub() async {
    if (!ApiService.hasToken) {
      showLoginPrompt(context, message: 'Sign in to found a campus club.');
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateClubScreen()),
    );
    if (result == true) {
      _loadClubs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _clubs.where((club) {
      final cat = (club['category'] ?? 'general').toString().toLowerCase();
      if (_categoryFilter != 'All Clubs' && cat != _categoryFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isEmpty) {
        return true;
      }
      final name = (club['name'] ?? '').toString().toLowerCase();
      final desc = (club['description'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          desc.contains(_searchQuery) ||
          cat.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(
        title: const Text(
          'Campus Clubs',
          style: TextStyle(
            color: ZynkColors.offWhite,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: ZynkColors.primary, size: 24),
            tooltip: 'Create Club',
            onPressed: _createClub,
          ),
        ],
      ),
      body: ZynkBackground(
        child: RefreshIndicator(
          color: ZynkColors.primary,
          onRefresh: _loadClubs,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            style: const TextStyle(color: ZynkColors.offWhite),
                            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                            decoration: InputDecoration(
                              hintText: 'Search clubs by name, category or topic...',
                              hintStyle: const TextStyle(color: ZynkColors.darkMuted),
                              prefixIcon: const Icon(Icons.search_rounded, color: ZynkColors.darkMuted),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, color: ZynkColors.darkMuted),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: ZynkColors.darkSurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: ZynkColors.darkBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: ZynkColors.darkBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: ZynkColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${filtered.length} ${filtered.length == 1 ? "Club" : "Clubs"} Found',
                                style: const TextStyle(
                                  color: ZynkColors.darkMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ZynkColors.darkSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: ZynkColors.darkBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _categoryFilter,
                                    dropdownColor: ZynkColors.darkSurface,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: ZynkColors.primary,
                                      size: 18,
                                    ),
                                    style: const TextStyle(
                                      color: ZynkColors.offWhite,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    items: _clubCategories.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      if (newValue != null) {
                                        setState(() => _categoryFilter = newValue);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
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
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: List.generate(
                            4,
                            (index) => const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: ZSkeleton(
                                width: double.infinity,
                                height: 80,
                                borderRadius: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: ZEmptyState(
                    icon: Icons.groups_rounded,
                    title: _searchQuery.isEmpty ? 'No clubs yet' : 'No matching clubs',
                    subtitle: _searchQuery.isEmpty
                        ? 'Be the first to found a club for your campus community.'
                        : 'Try searching with different keywords.',
                    actionLabel: _searchQuery.isEmpty ? 'Found a Club' : null,
                    onAction: _searchQuery.isEmpty ? _createClub : null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 650;
                            if (isWide) {
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 440,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  mainAxisExtent: 96,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  return _buildClubCard(filtered[index]);
                                },
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _buildClubCard(filtered[index]);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubCard(dynamic club) {
    final String clubName = club['name'] ?? 'Unnamed Club';
    final String clubId = (club['id'] ?? '').toString();
    final String? logoUrl = club['logo_url'];
    final String? category = club['category'];
    final String description = club['description'] ?? '';
    final int memberCount = (club['member_count'] as int?) ?? 1;

    final displayImage = (logoUrl != null && logoUrl.isNotEmpty)
        ? logoUrl
        : 'https://picsum.photos/seed/$clubId/200/200';

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ClubProfileScreen(
            clubId: clubId,
            clubName: clubName,
            clubData: club is Map<String, dynamic> ? club : null,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ZynkColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZynkColors.darkBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: displayImage,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: ZynkColors.darkSurface2,
                  child: const Icon(Icons.groups_rounded, color: ZynkColors.darkMuted),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          clubName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ZynkColors.darkText,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (category != null && category.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ZynkColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: ZynkColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description.isNotEmpty ? description : 'Campus Club • $memberCount ${memberCount == 1 ? "member" : "members"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZynkColors.darkMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: ZynkColors.darkMuted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
