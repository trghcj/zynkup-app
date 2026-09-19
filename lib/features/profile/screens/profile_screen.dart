import 'package:zynkup/core/widgets/zynk_skeleton.dart';
// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';

import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:zynkup/features/profile/widgets/dice_bear_avatar.dart';
import 'package:zynkup/features/profile/screens/avatar_gallery_screen.dart';

import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/core/utils/date_utils.dart';
import 'package:zynkup/core/services/bookmark_service.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/features/feed/screens/post_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  Map<String, int> _heatmapData = {};
  List<dynamic> _timeline = [];
  bool _loading = true;

  late TabController _tabController;

  final _nameC = TextEditingController();
  final _bioC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
    ApiService.userStatsChanged.addListener(_onStatsChanged);
    ApiService.latestNotification.addListener(_onNotificationReceived);
    ApiService.clubDeleted.addListener(_onClubDeleted);
    ApiService.clubCreated.addListener(_onClubCreated);
    ApiService.clubUpdated.addListener(_onClubUpdated);
    ApiService.eventCreated.addListener(_onEventCreated);
    ApiService.eventUpdated.addListener(_onEventUpdated);
  }

  void _onStatsChanged() {
    if (mounted && widget.userId == null) {
      _load(silent: true);
    }
  }

  void _onNotificationReceived() {
    final notif = ApiService.latestNotification.value;
    if (notif != null && mounted && widget.userId == null) {
      // Immediate optimistic update for zero latency
      final totalXpStr = notif['total_xp']?.toString();
      final xpGainedStr = notif['xp_gained']?.toString();
      final newLevelStr = notif['new_level']?.toString();
      if (_user != null) {
        setState(() {
          if (totalXpStr != null && int.tryParse(totalXpStr) != null) {
            _user!['xp'] = int.parse(totalXpStr);
          } else if (xpGainedStr != null && int.tryParse(xpGainedStr) != null) {
            _user!['xp'] = (_user!['xp'] as int? ?? 0) + int.parse(xpGainedStr);
          }
          if (newLevelStr != null && int.tryParse(newLevelStr) != null) {
            _user!['level'] = int.parse(newLevelStr);
          }
        });
      }
      _load(silent: true);
    }
  }

  void _onClubDeleted() {
    if (mounted && widget.userId == null) {
      _load(silent: true);
    }
  }

  void _onClubCreated() {
    if (mounted && widget.userId == null) {
      _load(silent: true);
    }
  }

  void _onClubUpdated() {
    if (mounted && widget.userId == null) {
      _load(silent: true);
    }
  }

  void _onEventCreated() {
    if (mounted && widget.userId == null) {
      _load(silent: true);
    }
  }

  void _onEventUpdated() {
    if (mounted && widget.userId == null) {
      _load(silent: true);
    }
  }

  @override
  void dispose() {
    ApiService.userStatsChanged.removeListener(_onStatsChanged);
    ApiService.latestNotification.removeListener(_onNotificationReceived);
    ApiService.clubDeleted.removeListener(_onClubDeleted);
    ApiService.clubCreated.removeListener(_onClubCreated);
    ApiService.clubUpdated.removeListener(_onClubUpdated);
    ApiService.eventCreated.removeListener(_onEventCreated);
    ApiService.eventUpdated.removeListener(_onEventUpdated);
    _tabController.dispose();
    _nameC.dispose();
    _bioC.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && _user == null) {
      setState(() => _loading = true);
    }
    // Each call is independent — one failure shouldn't kill the others
    final isMe = widget.userId == null;
    final userFuture = isMe
        ? ApiService.getCurrentUser(force: true).catchError((_) => null)
        : ApiService.getUserProfile(widget.userId!).catchError((_) => null);

    final results = await Future.wait([
      userFuture,
      ApiService.getHeatmapData().catchError((_) => <String, int>{}),
      ApiService.getMyEvents().catchError((_) => <dynamic>[]),
      ApiService.getMyRegistrations().catchError((_) => <dynamic>[]),
      ApiService.getTimeline().catchError((_) => <dynamic>[]),
    ]);
    if (!mounted) return;
    final user = results[0] as Map<String, dynamic>?;
    if (isMe && user != null && (user['banner_url'] == null || user['banner_url'].toString().isEmpty)) {
      final prefs = await SharedPreferences.getInstance();
      final localBanner = prefs.getString('profile_banner_url');
      if (localBanner != null && localBanner.isNotEmpty) {
        user['banner_url'] = localBanner;
      }
    }
    final heatmap = (results[1] is Map<String, int>)
        ? results[1] as Map<String, int>
        : <String, int>{};

    final timelineRaw = (results.length > 4 && results[4] is List)
        ? results[4] as List<dynamic>
        : <dynamic>[];

    setState(() {
      if (user != null) {
        _user = user;
        _nameC.text = user['name'] ?? '';
        _bioC.text = user['bio'] ?? '';
      }
      _heatmapData = heatmap;
      _timeline = timelineRaw;
      _loading = false;
    });
  }

  Future<void> _showAvatarOptions(int currentLevel) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? ZynkColors.darkSurface : Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    Icons.upload_rounded,
                    color: isDark ? ZynkColors.primary : const Color(0xFF65A30D),
                  ),
                  title: Text(
                    'Upload Photo',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: ZynkColors.gold),
                  title: Text(
                    'Choose from Avatar Gallery',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AvatarGalleryScreen(currentLevel: currentLevel),
                      ),
                    ).then((_) => _load());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.casino_rounded, color: ZynkColors.secondaryAccent),
                  title: Text(
                    'Random Cartoon Avatar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _randomizeAvatar();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBannerOptions() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasBanner = _user?['banner_url'] != null &&
        _user!['banner_url'].toString().trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? ZynkColors.darkSurface : Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    Icons.add_photo_alternate_rounded,
                    color: isDark ? ZynkColors.primary : const Color(0xFF65A30D),
                  ),
                  title: Text(
                    'Upload Custom Banner',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'PNG, JPG (Recommended landscape format)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadBanner();
                  },
                ),
                if (hasBanner)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: ZynkColors.error),
                    title: const Text(
                      'Remove Custom Banner',
                      style: TextStyle(
                        color: ZynkColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _removeBanner();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadBanner() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _loading = true);
    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _loading = false);
        return;
      }

      final url = await ApiService.uploadImageBytes(bytes, file.name);
      if (url != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_banner_url', url);

        await ApiService.updateProfile(bannerUrl: url);
        await _load();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _removeBanner() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_banner_url');
    await ApiService.updateProfile(bannerUrl: '');
    await _load();
  }

  Future<void> _pickAndUploadAvatar() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _loading = true);
    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _loading = false);
        return;
      }

      final url = await ApiService.uploadImageBytes(bytes, file.name);
      if (url != null) {
        await ApiService.updateProfile(avatarUrl: url);
        await _load();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _randomizeAvatar() async {
    setState(() => _loading = true);
    final newSeed = DateTime.now().millisecondsSinceEpoch.toString();
    await ApiService.updateProfile(avatarUrl: '', avatarSeed: newSeed);
    await _load();
  }

  Widget _buildFriendActionButton(Map<String, dynamic> user) {
    final status = user['friend_status'] ?? 'none';
    final requestId = user['friend_request_id'];

    if (status == 'friends') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: ZynkColors.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZynkColors.success),
        ),
        child: const Text(
          'Friends',
          style: TextStyle(
            color: ZynkColors.success,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (status == 'pending_sent') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey),
        ),
        child: const Text(
          'Request Sent',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    } else if (status == 'pending_received') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () async {
              if (requestId != null) {
                final success = await ApiService.acceptFriendRequest(requestId);
                if (success) _load();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZynkColors.success,
            ),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (requestId != null) {
                final success = await ApiService.declineFriendRequest(
                  requestId,
                );
                if (success) _load();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ZynkColors.error),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () async {
          if (widget.userId != null) {
            final success = await ApiService.sendFriendRequest(widget.userId!);
            if (success) _load();
          }
        },
        icon: const Icon(Icons.person_add, size: 18),
        label: const Text('Add Friend'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ZynkColors.gold,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return  Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _ProfileSkeleton(),
      );
    }

    final user = _user ?? {};
    final xp = user['xp'] ?? 0;
    final level = user['level'] ?? 1;
    final streak = user['streak'] ?? 0;
    final email = user['email'] ?? 'user@zynkup.com';
    final seed = user['avatar_seed'] ?? email;
    final avatarType = user['avatar_type'] ?? 'rings';

    // Level progress calculation
    int nextLevelXP = level * level * 25;
    int currentLevelXP = (level - 1) * (level - 1) * 25;

    // Fallback for edge cases
    if (nextLevelXP <= currentLevelXP) nextLevelXP = currentLevelXP + 25;

    double progress = (xp - currentLevelXP) / (nextLevelXP - currentLevelXP);
    if (progress.isNaN || progress.isInfinite) progress = 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ZynkBackground(
        child: RefreshIndicator(
          color: ZynkColors.primary,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            // ── Hero Profile Header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 150,
                          child: _buildBannerSection(user),
                        ),
                        Positioned(
                          top: 104,
                          child: _buildAvatarWidget(user, level, seed, avatarType),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user['name'] ?? 'Student',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user['email']?.split('@')[0] ?? 'user'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCollegeBadge(user, widget.userId == null),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? const Color(0xFFF8FAFC)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥 ', style: TextStyle(fontSize: 13)),
                        Text(
                          '$streak day streak',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('✨ ', style: TextStyle(fontSize: 13)),
                        Text(
                          'Level $level',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SizedBox(
                      width: 160,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Theme.of(context).brightness == Brightness.light
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : ZynkColors.darkSurface2,
                              color: ZynkColors.gold,
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${xp - currentLevelXP} / ${nextLevelXP - currentLevelXP} XP to Level ${level + 1}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _InlineStat(
                        count: '${user['events_created'] ?? 0}',
                        label: 'Created Events',
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Theme.of(context).colorScheme.outlineVariant,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      _InlineStat(
                        count: '${user['total_registered'] ?? user['attended'] ?? 0}',
                        label: 'Joined Events',
                      ),
                    ],
                  ),
                  if (widget.userId != null) ...[
                    const SizedBox(height: 24),
                    _buildFriendActionButton(user),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                indicatorColor: ZynkColors.primary,
                indicatorWeight: 2.5,
                labelColor: ZynkColors.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                dividerColor: Theme.of(context).colorScheme.outlineVariant,
                onTap: (index) => setState(() {}),
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard_rounded, size: 22)),
                  Tab(icon: Icon(Icons.history_rounded, size: 22)),
                  Tab(icon: Icon(Icons.workspace_premium_rounded, size: 22)),
                  Tab(icon: Icon(Icons.bookmark_rounded, size: 22)),
                ],
              ),
            ),

            // ── Tab Content ───────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverToBoxAdapter(
                child: [
                  _OverviewTab(
                    user: user,
                    heatmapData: _heatmapData,
                    onBioUpdated: _load,
                    isMe: widget.userId == null,
                  ),
                  _TimelineTab(timeline: _timeline),
                  _BadgesTab(user: user),
                  _BookmarksTab(isMe: widget.userId == null),
                ][_tabController.index],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBannerSection(Map<String, dynamic> user) {
    final bannerUrl = user['banner_url'];
    final hasCustomBanner =
        bannerUrl != null && bannerUrl.toString().trim().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B26) : const Color(0xFFE2E8F0),
            gradient: hasCustomBanner
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF1E2638),
                            Color(0xFF111827),
                            Color(0xFF0F172A),
                          ]
                        : const [
                            Color(0xFFF1F5F9),
                            Color(0xFFE2E8F0),
                            Color(0xFFCBD5E1),
                          ],
                  ),
          ),
          child: hasCustomBanner
              ? CachedNetworkImage(
                  imageUrl: bannerUrl.toString(),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 150,
                  placeholder: (context, url) => Container(
                    color: isDark ? const Color(0xFF161B26) : const Color(0xFFE2E8F0),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? const Color(0xFF161B26) : const Color(0xFFE2E8F0),
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isDark ? ZynkColors.primary : const Color(0xFF65A30D))
                              .withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 10,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isDark ? ZynkColors.gold : const Color(0xFF3B82F6))
                              .withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        Icons.school_rounded,
                        size: 44,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.14),
                      ),
                    ),
                  ],
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  (isDark ? ZynkColors.darkBg : Theme.of(context).scaffoldBackgroundColor)
                      .withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),
        if (Navigator.canPop(context))
          Positioned(
            top: 14,
            left: 14,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (widget.userId == null)
          Positioned(
            top: 14,
            right: 14,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showBannerOptions,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'Banner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarWidget(
    Map<String, dynamic> user,
    int level,
    String seed,
    String avatarType,
  ) {
    final bool canEdit = widget.userId == null;

    return MouseRegion(
      cursor: canEdit ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canEdit ? () => _showAvatarOptions(level) : null,
        child: SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: (user['avatar_url'] != null &&
                            user['avatar_url'].toString().isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: user['avatar_url'],
                            fit: BoxFit.cover,
                            width: 92,
                            height: 92,
                            memCacheWidth: 260,
                          )
                        : DiceBearAvatar(
                            seed: seed,
                            type: avatarType,
                            size: 92,
                          ),
                  ),
                ),
              ),
              if (canEdit)
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showAvatarOptions(level),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildCollegeBadge(Map<String, dynamic> user, bool isMe) {
    final college = (user['college'] as String?)?.trim() ?? '';
    final hasCollege = college.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: isMe
          ? () => _showEditCollegeDialog(context, college, _load)
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: hasCollege
              ? (isDark
                  ? ZynkColors.primary.withValues(alpha: 0.12)
                  : ZynkColors.primary.withValues(alpha: 0.08))
              : (isDark
                  ? Theme.of(context).colorScheme.surface
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasCollege
                ? ZynkColors.primary.withValues(alpha: 0.35)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_rounded,
              size: 15,
              color: hasCollege
                  ? ZynkColors.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 7),
            Text(
              hasCollege ? college : (isMe ? 'Add College' : 'No College Listed'),
              style: TextStyle(
                color: hasCollege
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 5),
              Icon(
                hasCollege ? Icons.edit_rounded : Icons.add_rounded,
                size: 13,
                color: ZynkColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showEditCollegeDialog(
  BuildContext context,
  String currentCollege,
  VoidCallback onUpdated,
) async {
  final controller = TextEditingController(text: currentCollege);
  bool saving = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : ZynkColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ZynkColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_rounded,
                color: ZynkColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'College / Campus',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your college or university name to show it on your profile and connect with campus peers.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. MAIT, IIT Delhi, DTU',
                prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFFF8FAFC)
                    : ZynkColors.darkSurface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: ZynkColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    setDialogState(() => saving = true);
                    final success = await ApiService.updateProfile(
                      college: controller.text.trim(),
                    );
                    if (success && ctx.mounted) {
                      Navigator.pop(ctx, true);
                    } else {
                      setDialogState(() => saving = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZynkColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (result == true) {
    onUpdated();
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, int> heatmapData;
  final VoidCallback onBioUpdated;
  final bool isMe;
  const _OverviewTab({
    required this.user,
    required this.heatmapData,
    required this.onBioUpdated,
    required this.isMe,
  });

  Future<void> _editBio(BuildContext context) async {
    final controller = TextEditingController(text: user['bio'] ?? '');
    bool saving = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Bio'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write something about yourself...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      final success = await ApiService.updateUser({
                        'bio': controller.text.trim(),
                      });
                      if (success && ctx.mounted) {
                        Navigator.pop(ctx, true);
                      } else {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(color: ZynkColors.gold),
                    ),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      onBioUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedBadges = _profileBadges(
      user,
    ).where((badge) => badge.unlocked).take(5).toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bio',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (isMe)
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    size: 16,
                    color: ZynkColors.gold,
                  ),
                  onPressed: () => _editBio(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            user['bio']?.isNotEmpty == true ? user['bio'] : 'No bio set yet.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Achievements',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: unlockedBadges.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Earn your first badge by joining or creating an event.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: unlockedBadges.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, index) {
                      final badge = unlockedBadges[index];
                      return _BadgeIcon(badge: badge);
                    },
                  ),
          ),

          if (isMe) ...[
            const SizedBox(height: 24),
            Text(
              'Friends & Requests',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<dynamic>>(
              future: Future.wait([
                ApiService.getPendingFriendRequests(),
                ApiService.getFriends(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: ZynkColors.gold),
                  );
                }
                if (!snapshot.hasData) return const SizedBox();
                final pending = snapshot.data![0] as List<dynamic>;
                final friends = snapshot.data![1] as List<dynamic>;

                if (pending.isEmpty && friends.isEmpty) {
                  return Text(
                    'No friends or pending requests.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  );
                }

                return Column(
                  children: [
                    if (pending.isNotEmpty) ...[
                       Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Pending Requests',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...pending.map((r) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              r['sender_avatar'] ?? '',
                            ),
                          ),
                          title: Text(
                            r['sender_name'] ?? 'User',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: ZynkColors.success,
                                ),
                                onPressed: () async {
                                  await ApiService.acceptFriendRequest(r['id']);
                                  onBioUpdated(); // trigger reload
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: ZynkColors.error,
                                ),
                                onPressed: () async {
                                  await ApiService.declineFriendRequest(
                                    r['id'],
                                  );
                                  onBioUpdated(); // trigger reload
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    if (friends.isNotEmpty) ...[
                       Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'My Friends',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...friends.map((f) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfileScreen(userId: f['user_id']),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              f['avatar_url'] ?? '',
                            ),
                          ),
                          title: Text(
                            f['name'] ?? 'User',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.person_remove,
                              color: ZynkColors.error,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                  title: Text(
                                    'Unfriend',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  ),
                                  content: Text(
                                    'Remove ${f['name'] ?? 'User'} from your friends?',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(
                                          color: ZynkColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final success = await ApiService.removeFriend(
                                  f['user_id'],
                                );
                                if (success) onBioUpdated(); // Trigger refresh
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  final List<dynamic> timeline;
  const _TimelineTab({required this.timeline});

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        title: 'No Activity Yet',
        message:
            'Join clubs, register for events, or post to your feed to see your activity here.',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: timeline.length,
        itemBuilder: (context, index) {
          final item = timeline[index];
          final type = item['type'] as String? ?? '';
          final title = item['title'] as String? ?? '';
          final dateStr = item['date'] as String?;

          IconData icon;
          Color color;
          if (type == 'event_registration') {
            icon = Icons.event_available_rounded;
            color = ZynkColors.accent;
          } else if (type == 'event_created') {
            icon = Icons.event_note_rounded;
            color = ZynkColors.secondaryAccent;
          } else if (type == 'club_created') {
            icon = Icons.group_add_rounded;
            color = ZynkColors.orange;
          } else if (type == 'club_join') {
            icon = Icons.groups_rounded;
            color = ZynkColors.primary;
          } else {
            icon = Icons.post_add_rounded;
            color = ZynkColors.gold;
          }

          final timeAgo = ZynkDateUtils.formatTimeAgo(dateStr);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
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
          );
        },
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final _ProfileBadge badge;

  const _BadgeIcon({required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = badge.unlocked
        ? badge.color
        : ZynkColors.darkMuted.withValues(alpha: 0.5);
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: badge.unlocked
                  ? color.withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: badge.unlocked
                    ? color.withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(badge.icon, color: color, size: 24),
                if (!badge.unlocked)
                   Positioned(
                    right: 4,
                    bottom: 4,
                    child: Icon(
                      Icons.lock_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      size: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: badge.unlocked
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsTab extends StatefulWidget {
  const _EventsTab({
    required this.createdEvents,
    required this.joinedEvents,
    required this.onRefresh,
  });

  final List<Event> createdEvents;
  final List<Event> joinedEvents;
  final Future<void> Function() onRefresh;

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    var allEvents = [
      ...widget.createdEvents.map((event) => (event: event, label: 'Created')),
      ...widget.joinedEvents.map((event) => (event: event, label: 'Joined')),
    ];

    if (_selectedFilter == 'Created') {
      allEvents = allEvents.where((e) => e.label == 'Created').toList();
    } else if (_selectedFilter == 'Joined') {
      allEvents = allEvents.where((e) => e.label == 'Joined').toList();
    }

    if (widget.createdEvents.isEmpty && widget.joinedEvents.isEmpty) {
      return const _EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No events yet',
        message: 'Events you create or join will appear here.',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Events',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(ZynkRadius.md),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    icon:  Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'All',
                        child: Text(
                          'All',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Created',
                        child: Text(
                          'Created',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Joined',
                        child: Text(
                          'Joined',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (allEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  'No events found for this filter.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 920
                    ? 3
                    : constraints.maxWidth >= 620
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allEvents.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: columns == 1 ? 1.35 : 0.92,
                  ),
                  itemBuilder: (context, index) {
                    final item = allEvents[index];
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: EventCardWidget(
                            event: item.event,
                            onTap: () async {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) =>
                                    EventDetailsScreen(event: item.event),
                              );
                              await widget.onRefresh();
                            },
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: ZynkColors.deepOlive.withValues(
                                alpha: 0.82,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: ZynkColors.sand.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BadgesTab extends StatelessWidget {
  final Map<String, dynamic> user;
  const _BadgesTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> badges = user['badges'] ?? [];
    if (badges.isEmpty) {
      return const _EmptyState(
        icon: Icons.workspace_premium_rounded,
        title: 'No Badges Yet',
        message:
            'Attend events, post to your feed, and engage with the campus to earn badges.',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: badges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final badge = badges[index];
          final bool unlocked = badge['unlocked'] ?? true;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(ZynkRadius.lg),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? ZynkColors.primary.withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: unlocked ? ZynkColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge['name'] ?? 'Badge',
                        style: TextStyle(
                          color: unlocked
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge['description'] ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BadgeTile extends StatefulWidget {
  const _BadgeTile({required this.badge});
  final _ProfileBadge badge;

  @override
  State<_BadgeTile> createState() => _BadgeTileState();
}

class _BadgeTileState extends State<_BadgeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;

    return GestureDetector(
      onTapDown: (_) => _anim.reverse(),
      onTapUp: (_) => _anim.forward(),
      onTapCancel: () => _anim.forward(),
      child: ScaleTransition(
        scale: _anim,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(ZynkRadius.lg),
            border: Border.all(
              color: badge.unlocked
                  ? Theme.of(context).colorScheme.outlineVariant
                  : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BadgeIcon(badge: badge),
              const SizedBox(height: 12),
              Text(
                badge.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: badge.unlocked
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarksTab extends StatefulWidget {
  final bool isMe;
  const _BookmarksTab({required this.isMe});

  @override
  State<_BookmarksTab> createState() => _BookmarksTabState();
}

class _BookmarksTabState extends State<_BookmarksTab> {
  String _filter = 'Events';
  List<Event> _events = [];
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    BookmarkService.bookmarkUpdateNotifier.addListener(_loadBookmarks);
  }

  @override
  void dispose() {
    BookmarkService.bookmarkUpdateNotifier.removeListener(_loadBookmarks);
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    final events = await BookmarkService.getBookmarkedEvents();
    final posts = await BookmarkService.getBookmarkedPosts();
    if (mounted) {
      setState(() {
        _events = events;
        _posts = posts;
        _loading = false;
      });
    }
  }

  Future<void> _handleRemoveEventBookmark(String eventId) async {
    await BookmarkService.removeEventBookmark(eventId);
    _loadBookmarks();
    if (!mounted) return;
    BookmarkService.showBookmarkToast(
      context,
      isBookmarked: false,
      itemType: 'Event',
    );
  }

  Future<void> _handleRemovePostBookmark(dynamic postId) async {
    await BookmarkService.removePostBookmark(postId);
    _loadBookmarks();
    if (!mounted) return;
    BookmarkService.showBookmarkToast(
      context,
      isBookmarked: false,
      itemType: 'Post',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMe) {
      return const _EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Private Bookmarks',
        message: 'Bookmarks are private to the account owner.',
      );
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: ZynkColors.primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _filter == 'Events'
                    ? 'Saved Events (${_events.length})'
                    : 'Saved Posts (${_posts.length})',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filter,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ZynkColors.primary,
                      size: 18,
                    ),
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Events', child: Text('Events')),
                      DropdownMenuItem(value: 'Feed', child: Text('Feed')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_filter == 'Events') ...[
          if (_events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No Saved Events',
                message:
                    'Tap the bookmark icon on any event to save it for quick access.',
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final event = _events[index];
                  return _SavedEventCard(
                    event: event,
                    onRemove: () => _handleRemoveEventBookmark(event.id),
                  );
                },
              ),
            ),
        ] else ...[
          if (_posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No Saved Posts',
                message:
                    'Tap the save button on any feed post to access it here.',
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _posts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final rawId = post['id'];
                  final postId = rawId is int
                      ? rawId
                      : (int.tryParse(rawId?.toString() ?? '') ?? 0);
                  return _SavedPostGridItem(
                    post: post,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(
                            postId: postId,
                            initialPost: post,
                          ),
                        ),
                      );
                    },
                    onRemove: () => _handleRemovePostBookmark(rawId),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _SavedEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onRemove;
  const _SavedEventCard({required this.event, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage =
        event.imageUrls.isNotEmpty && event.imageUrls.first.trim().isNotEmpty;
    final dateFormatted = DateFormat('EEE, MMM d • h:mm a').format(event.date);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: event.imageUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: isDark
                              ? ZynkColors.darkSurface2
                              : const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(
                              Icons.event_rounded,
                              color: ZynkColors.primary,
                              size: 28,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: isDark
                              ? ZynkColors.darkSurface2
                              : const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(
                              Icons.event_rounded,
                              color: ZynkColors.primary,
                              size: 28,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: ZynkColors.primary.withValues(alpha: 0.12),
                        child: const Center(
                          child: Icon(
                            Icons.event_rounded,
                            color: ZynkColors.primary,
                            size: 30,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ZynkColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      event.category.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ZynkColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dateFormatted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (event.venue.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.bookmark_rounded,
                color: ZynkColors.primary,
                size: 22,
              ),
              tooltip: 'Remove bookmark',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPostGridItem extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedPostGridItem({
    required this.post,
    required this.onTap,
    required this.onRemove,
  });

  static String? _getYouTubeId(String? url) {
    if (url == null || url.isEmpty) return null;
    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerUrl = (post['banner_url'] as String?)?.trim();
    final imageUrl = (post['image_url'] as String?)?.trim();
    final linkUrl = (post['link_url'] as String?)?.trim();
    final ytId = _getYouTubeId(linkUrl);
    final ytThumbnail = ytId != null ? 'https://img.youtube.com/vi/$ytId/hqdefault.jpg' : null;

    final mediaUrl = (bannerUrl != null && bannerUrl.isNotEmpty)
        ? bannerUrl
        : (imageUrl != null && imageUrl.isNotEmpty)
            ? imageUrl
            : ytThumbnail;

    final isVideo = ytThumbnail != null;
    final authorName = (post['author_name'] as String?) ?? 'User';
    final authorAvatar = (post['author_avatar'] as String?)?.trim();
    final content = (post['content'] as String? ?? '').trim();
    final likes = post['likes'] as int? ?? 0;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mediaUrl != null && mediaUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: isDark ? ZynkColors.darkSurface : const Color(0xFFE2E8F0),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ZynkColors.primary),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => _buildTextFallback(context, isDark, authorName, authorAvatar, content),
              )
            else
              _buildTextFallback(context, isDark, authorName, authorAvatar, content),

            // Vignette gradient overlay at bottom with stats and bookmark indicator
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    if (likes > 0) ...[
                      const Icon(Icons.favorite_rounded, size: 10, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        '$likes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    const Icon(
                      Icons.bookmark_rounded,
                      size: 13,
                      color: ZynkColors.primary,
                    ),
                  ],
                ),
              ),
            ),

            // Top-right media badge (Video / Gallery / Text)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  isVideo
                      ? Icons.play_arrow_rounded
                      : (mediaUrl != null
                          ? (bannerUrl != null && imageUrl != null
                              ? Icons.filter_none_rounded
                              : Icons.image_rounded)
                          : Icons.article_rounded),
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFallback(
    BuildContext context,
    bool isDark,
    String authorName,
    String? authorAvatar,
    String content,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [ZynkColors.darkSurface, ZynkColors.darkSurface2]
              : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 9,
                backgroundImage: (authorAvatar != null && authorAvatar.isNotEmpty)
                    ? CachedNetworkImageProvider(authorAvatar)
                    : null,
                backgroundColor: ZynkColors.primary.withValues(alpha: 0.2),
                child: (authorAvatar == null || authorAvatar.isEmpty)
                    ? Text(
                        authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ZynkColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Text(
              content.isNotEmpty ? content : 'Zynkup Post',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: ZynkColors.darkMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen_rounded, color: ZynkColors.primary),
              title: const Text('Open Post', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_remove_rounded, color: ZynkColors.error),
              title: const Text('Remove from Bookmarks', style: TextStyle(color: ZynkColors.error, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                onRemove();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: ZynkGradients.cardSurface,
              borderRadius: BorderRadius.circular(ZynkRadius.xl),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: ZynkShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: ZynkColors.gold.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: ZynkColors.gold.withValues(alpha: 0.7),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBadge {
  const _ProfileBadge({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
}

List<_ProfileBadge> _profileBadges(Map<String, dynamic> user) {
  final raw = user['badges'];
  
  // If badges is a list of Maps (legacy or different format)
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return raw
        .whereType<Map>()
        .map(
          (item) => _ProfileBadge(
            name: (item['name'] ?? '').toString(),
            description: (item['description'] ?? '').toString(),
            icon: _badgeIcon((item['icon'] ?? '').toString()),
            color: _badgeColor((item['color'] ?? '').toString()),
            unlocked: item['unlocked'] == true,
          ),
        )
        .where((badge) => badge.name.isNotEmpty)
        .toList();
  }

  // Predefined badges
  final eventsCreated = user['events_created'] ?? 0;
  final attended = user['attended'] ?? 0;
  final totalRegistered = user['total_registered'] ?? 0;
  final level = user['level'] ?? 1;
  final streak = user['streak'] ?? 0;
  final role = (user['role'] ?? 'user').toString();
  final id = user['id'] ?? 999;
  final totalAttendees = user['total_attendees'] ?? 0;

  final allBadges = [
    _ProfileBadge(
      name: 'First Event',
      description: 'Register for your first event.',
      icon: Icons.event_available_rounded,
      color: const Color(0xFFF97316),
      unlocked: (totalRegistered as int) >= 1,
    ),
    _ProfileBadge(
      name: 'Explorer',
      description: 'Register for 3 events.',
      icon: Icons.explore_rounded,
      color: const Color(0xFF38BDF8),
      unlocked: totalRegistered >= 3,
    ),
    _ProfileBadge(
      name: 'First Creator',
      description: 'Create your first event.',
      icon: Icons.add_circle_rounded,
      color: const Color(0xFFA78BFA),
      unlocked: (eventsCreated as int) >= 1,
    ),
    _ProfileBadge(
      name: 'Rising Star',
      description: 'Reach level 3.',
      icon: Icons.star_rounded,
      color: const Color(0xFFFACC15),
      unlocked: (level as int) >= 3,
    ),
    _ProfileBadge(
      name: 'Community Hero',
      description: 'Attend 5 events.',
      icon: Icons.volunteer_activism_rounded,
      color: const Color(0xFF22C55E),
      unlocked: (attended as int) >= 5,
    ),
    _ProfileBadge(
      name: '7-Day Streak',
      description: 'Keep a 7-day activity streak.',
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFEF4444),
      unlocked: (streak as int) >= 7,
    ),
    _ProfileBadge(
      name: 'Verified Organizer',
      description: 'Become an organizer or admin.',
      icon: Icons.verified_rounded,
      color: const Color(0xFF14B8A6),
      unlocked: role == 'organizer' || role == 'admin',
    ),
    _ProfileBadge(
      name: 'Founding Member',
      description: 'Be among the first 100 Zynkup members.',
      icon: Icons.workspace_premium_rounded,
      color: const Color(0xFFFB7185),
      unlocked: (id as int) <= 100,
    ),
    _ProfileBadge(
      name: 'Crowd Magnet',
      description: 'Bring 10 total attendees to your events.',
      icon: Icons.groups_rounded,
      color: const Color(0xFF60A5FA),
      unlocked: (totalAttendees as int) >= 10,
    ),
    _ProfileBadge(
      name: 'Elite Member',
      description: 'Reach level 10.',
      icon: Icons.military_tech_rounded,
      color: const Color(0xFFF59E0B),
      unlocked: level >= 10,
    ),
  ];

  // If badges is a list of strings (badge names), sync unlocks with that list
  if (raw is List && raw.isNotEmpty && raw.first is String) {
    final unlockedNames = raw.map((e) => e.toString()).toSet();
    return allBadges.map((b) => _ProfileBadge(
      name: b.name,
      description: b.description,
      icon: b.icon,
      color: b.color,
      unlocked: unlockedNames.contains(b.name),
    )).toList();
  }

  // Fallback to computed stats
  return allBadges;
}

IconData _badgeIcon(String icon) {
  switch (icon) {
    case 'event_available':
      return Icons.event_available_rounded;
    case 'explore':
      return Icons.explore_rounded;
    case 'add_circle':
      return Icons.add_circle_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'volunteer_activism':
      return Icons.volunteer_activism_rounded;
    case 'local_fire_department':
      return Icons.local_fire_department_rounded;
    case 'verified':
      return Icons.verified_rounded;
    case 'workspace_premium':
      return Icons.workspace_premium_rounded;
    case 'groups':
      return Icons.groups_rounded;
    case 'military_tech':
      return Icons.military_tech_rounded;
  }
  return Icons.workspace_premium_rounded;
}

Color _badgeColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return ZynkColors.primary;
  return Color(0xFF000000 | value);
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const SizedBox(height: 48),
          const Center(
            child: ZSkeleton(width: 120, height: 120, isCircle: true),
          ),
          const SizedBox(height: 24),
          const Center(child: ZSkeleton(width: 200, height: 32)),
          const SizedBox(height: 12),
          const Center(child: ZSkeleton(width: 150, height: 16)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (index) => Column(
                children: const [
                  ZSkeleton(width: 40, height: 24),
                  SizedBox(height: 8),
                  ZSkeleton(width: 60, height: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          const ZSkeleton(width: double.infinity, height: 48, borderRadius: 12),
          const SizedBox(height: 32),
          Column(
            children: List.generate(
              3,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: ZSkeleton(
                  width: double.infinity,
                  height: 120,
                  borderRadius: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String count;
  final String label;
  const _InlineStat({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
