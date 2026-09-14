import 'package:zynkup/core/widgets/zynk_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/theme/theme_provider.dart';
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
import 'package:zynkup/features/clubs/widgets/edit_club_sheet.dart';

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
    ApiService.clubUpdated.addListener(_onClubUpdated);
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

  void _onClubUpdated() {
    final updated = ApiService.clubUpdated.value;
    if (updated != null && mounted && updated['id'].toString() == widget.clubId) {
      setState(() {
        _club = updated;
      });
    }
  }

  @override
  void dispose() {
    ApiService.clubUpdated.removeListener(_onClubUpdated);
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
    final isDark = themeProvider.isDark;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? ZynkColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        title: Text(
          'Delete Club?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0E1117),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This action cannot be undone. All events, members, and posts will be deleted.',
          style: TextStyle(
            color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: ZynkColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final success = await ApiService.deleteClub(int.parse(widget.clubId));
    if (!mounted) return;
    if (success) {
      nav.pop(true); // Close club profile and signal deletion
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: ZynkColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Club deleted successfully.',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0E1117),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          elevation: isDark ? 2 : 6,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: ZynkColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed to delete club. Please try again.',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0E1117),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
            ),
          ),
          elevation: isDark ? 2 : 6,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  bool get _isClubOwner {
    if (_club == null || _currentUser == null) return false;
    return _club!['creator_id']?.toString() == _currentUser!['id']?.toString();
  }

  bool get _isClubAdmin {
    if (_currentUser == null) return false;
    final record = _clubMembers.firstWhere(
      (m) => m['user_id']?.toString() == _currentUser!['id']?.toString(),
      orElse: () => null,
    );
    if (record != null) {
      final role = record['role']?.toString().toLowerCase() ?? 'member';
      return role == 'admin';
    }
    return false;
  }

  bool get _canEditClub => _isClubOwner || _isClubAdmin;

  Future<void> _editClub() async {
    if (_club == null) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditClubSheet(club: _club!),
    );
    if (updated != null && mounted) {
      setState(() {
        _club = updated;
      });
      _loadClub();
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
    final isDark = themeProvider.isDark;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Uploading photo to gallery...',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0E1117),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        elevation: isDark ? 2 : 8,
        duration: const Duration(seconds: 15),
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
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: ZynkColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Image uploaded successfully!',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0E1117),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              elevation: isDark ? 2 : 8,
            ),
          );
        }
      } else {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: ZynkColors.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to upload image.',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0E1117),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              elevation: isDark ? 2 : 8,
            ),
          );
        }
      }
    } catch (e) {
      messenger.clearSnackBars();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: ZynkColors.error, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: $e',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0E1117),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            elevation: isDark ? 2 : 8,
          ),
        );
      }
    }
  }

  Future<void> _showRoleAssignmentDialog(int userId, String name, String currentRole) async {
    final controller = TextEditingController(text: currentRole);
    final messenger = ScaffoldMessenger.of(context);
    final isDark = themeProvider.isDark;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedRole = controller.text.trim().toLowerCase();
            final presets = [
              {'role': 'admin', 'label': 'Admin', 'icon': Icons.admin_panel_settings_rounded},
              {'role': 'moderator', 'label': 'Moderator', 'icon': Icons.security_rounded},
              {'role': 'member', 'label': 'Member', 'icon': Icons.person_outline_rounded},
            ];

            return AlertDialog(
              backgroundColor: isDark ? ZynkColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? ZynkColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.military_tech_rounded,
                      color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Role',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0E1117),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'for $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Give this member a club role. You can type any custom title or select a preset below.',
                      style: TextStyle(
                        color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Role Name Input
                    TextField(
                      controller: controller,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0E1117),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Role Name',
                        hintText: 'e.g. Moderator, Lead, Organizer',
                        labelStyle: TextStyle(
                          color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                        ),
                        hintStyle: TextStyle(
                          color: isDark ? ZynkColors.darkMuted.withValues(alpha: 0.5) : const Color(0xFF94A3B8),
                        ),
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'PRESETS',
                      style: TextStyle(
                        color: isDark ? ZynkColors.darkMuted : const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Preset Chips Row with interactive highlight
                    Row(
                      children: presets.map((preset) {
                        final isSelected = selectedRole == (preset['role'] as String).toLowerCase();
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                controller.text = preset['role'] as String;
                                setDialogState(() {});
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                          ? ZynkColors.primary.withValues(alpha: 0.18)
                                          : const Color(0xFFEFF6FF))
                                      : (isDark
                                          ? ZynkColors.darkSurface2
                                          : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? ZynkColors.primary : const Color(0xFF2563EB))
                                        : (isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      preset['icon'] as IconData,
                                      size: 18,
                                      color: isSelected
                                          ? (isDark ? ZynkColors.primary : const Color(0xFF2563EB))
                                          : (isDark ? ZynkColors.darkMuted : const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      preset['label'] as String,
                                      style: TextStyle(
                                        color: isSelected
                                            ? (isDark ? Colors.white : const Color(0xFF0E1117))
                                            : (isDark ? ZynkColors.darkMuted : const Color(0xFF64748B)),
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: isDark ? ZynkColors.primary : const Color(0xFF0E1117),
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final newRole = controller.text.trim();
                          if (newRole.isNotEmpty) {
                            Navigator.pop(dialogContext);
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
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: ZynkColors.success, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Successfully assigned "$newRole" role to $name.',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFF0E1117),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    elevation: isDark ? 2 : 8,
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: ZynkColors.error, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Failed to update member role.',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFF0E1117),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    elevation: isDark ? 2 : 8,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Text(
                          'Save Role',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeMember(int userId, String name) async {
    final isDark = themeProvider.isDark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? ZynkColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        title: Text(
          'Remove Member',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0E1117),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove $name from the club?',
          style: TextStyle(
            color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZynkColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
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
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: ZynkColors.success, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$name removed from club',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0E1117),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                ),
                elevation: isDark ? 2 : 8,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: ZynkColors.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Failed to remove member',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0E1117),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                ),
                elevation: isDark ? 2 : 8,
              ),
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: ZynkBackground(
            child: _loading
                ? const _ClubProfileSkeleton()
                : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: 280,
                      pinned: true,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      leading: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      flexibleSpace: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCollapsed = constraints.biggest.height <=
                              (kToolbarHeight + MediaQuery.of(context).padding.top + 30);
                          return FlexibleSpaceBar(
                            title: Text(
                              widget.clubName,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isCollapsed
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.white,
                                shadows: isCollapsed
                                    ? null
                                    : const [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 12,
                                          offset: Offset(0, 1),
                                        ),
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 6,
                                        ),
                                      ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            centerTitle: true,
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: bannerImage,
                                  fit: BoxFit.cover,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.45),
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.45),
                                        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
                                        Theme.of(context).scaffoldBackgroundColor,
                                      ],
                                      stops: const [0.0, 0.35, 0.65, 0.88, 1.0],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      actions: [
                        if (_canEditClub)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.35),
                              child: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                                onSelected: (val) {
                                  if (val == 'edit') _editClub();
                                  if (val == 'delete') _deleteClub();
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded, color: Theme.of(ctx).colorScheme.onSurface, size: 18),
                                        const SizedBox(width: 10),
                                        Text('Edit Club', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
                                      ],
                                    ),
                                  ),
                                  if (_isClubOwner)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_rounded, color: ZynkColors.error, size: 18),
                                          SizedBox(width: 10),
                                          Text('Delete Club', style: TextStyle(color: ZynkColors.error)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: CachedNetworkImageProvider(logoImage),
                              backgroundColor: ZynkColors.darkSurface2,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.clubName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_club?['category'] ?? 'Community'} • ${_club?['member_count'] ?? 0} members',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_club?['college'] != null && _club!['college'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: ZynkColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: ZynkColors.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_balance_rounded, size: 14, color: ZynkColors.primary),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _club!['college'],
                                        style: const TextStyle(
                                          color: ZynkColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (_club == null || _currentUser == null || (_club!['creator_id']?.toString() != _currentUser!['id']?.toString()))
                              SizedBox(
                                width: double.infinity,
                                child: ZynkButton(
                                  height: 44,
                                  label: _isMember ? 'Joined' : 'Join',
                                  outlined: _isMember,
                                  icon: _isMember ? Icons.check_rounded : Icons.add_rounded,
                                  onTap: _toggleMembership,
                                ),
                              ),
                            const SizedBox(height: 24),
                            Text(
                              _club != null && _club!['description'] != null
                                  ? _club!['description']
                                  : 'The official ${widget.clubName} of MAIT. We build, create, and innovate together.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, height: 1.5),
                              textAlign: TextAlign.center,
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
                          indicatorColor: Theme.of(context).brightness == Brightness.light
                              ? const Color(0xFF65A30D)
                              : ZynkColors.gold,
                          indicatorWeight: 3,
                          labelColor: Theme.of(context).brightness == Brightness.light
                              ? const Color(0xFF3F6212)
                              : ZynkColors.gold,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
                decoration: BoxDecoration(
                  color: ZynkColors.darkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: ZynkColors.gold),
                title:  Text(
                  'Watch Full Feed / View Discussion',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
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
               Divider(color: Theme.of(context).colorScheme.outlineVariant),
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
                      final isDark = themeProvider.isDark;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: ZynkColors.success, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Post reported successfully.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0E1117),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                          ),
                          elevation: isDark ? 2 : 8,
                        ),
                      );
                    } else {
                      final isDark = themeProvider.isDark;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: ZynkColors.error, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Failed to report post.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0E1117),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                          ),
                          elevation: isDark ? 2 : 8,
                        ),
                      );
                    }
                  }
                },
              ),
              if (isAuthor) ...[
                 Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.onSurface),
                  title:  Text(
                    'Edit Post',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
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
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        title: const Text('Delete Post', style: TextStyle(color: ZynkColors.error)),
                        content: Text('Are you sure you want to delete this post?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(ZynkRadius.lg),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                        final postId = post['id'];
                        final baseUrl = kIsWeb ? Uri.base.origin : 'https://zynkup-app.vercel.app';
                        final shareUrl = '$baseUrl/feed/$postId';
                        final snippet = (post['content'] ?? '').toString().trim();
                        final text = snippet.isNotEmpty
                            ? '$snippet\n\nCheck out this post on Zynkup:\n$shareUrl'
                            : 'Check out this post on Zynkup:\n$shareUrl';
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await Share.share(text);
                        } catch (_) {
                          await Clipboard.setData(ClipboardData(text: text));
                          final isDark = themeProvider.isDark;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Copied post link to clipboard!',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0E1117),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: isDark ? ZynkColors.darkSurface2 : Colors.white,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                                ),
                              ),
                              elevation: isDark ? 2 : 8,
                            ),
                          );
                        }
                      },

                      onReact: (emoji) async {
                        final postId = post['id'] as int?;
                        if (postId != null) {
                          final currentReaction = post['user_reaction'] as String?;
                          final reactions = Map<String, dynamic>.from(post['reactions'] as Map<String, dynamic>? ?? {});
                          
                          setState(() {
                            if (currentReaction == emoji) {
                              post['user_reaction'] = null;
                              reactions[emoji] = (reactions[emoji] ?? 1) - 1;
                              if (reactions[emoji] <= 0) reactions.remove(emoji);
                            } else {
                              if (currentReaction != null) {
                                reactions[currentReaction] = (reactions[currentReaction] ?? 1) - 1;
                                if (reactions[currentReaction] <= 0) reactions.remove(currentReaction);
                              }
                              post['user_reaction'] = emoji;
                              reactions[emoji] = (reactions[emoji] ?? 0) + 1;
                            }
                            post['reactions'] = reactions;
                          });

                          await ApiService.reactToFeedPost(postId, emoji);
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
                       Text(
                        'Your next campus moment starts here',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 15, fontWeight: FontWeight.w600),
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
                  title: Text(name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
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
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
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
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}
class _ClubProfileSkeleton extends StatelessWidget {
  const _ClubProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
         SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            background: ZSkeleton(width: double.infinity, height: 280, borderRadius: 0),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ZSkeleton(width: 80, height: 80, isCircle: true),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          ZSkeleton(width: 200, height: 24),
                          SizedBox(height: 8),
                          ZSkeleton(width: 100, height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const ZSkeleton(width: double.infinity, height: 60, borderRadius: 12),
                const SizedBox(height: 24),
                const ZSkeleton(width: double.infinity, height: 14),
                const SizedBox(height: 8),
                const ZSkeleton(width: 250, height: 14),
              ],
            ),
          ),
        )
      ],
    );
  }
}
