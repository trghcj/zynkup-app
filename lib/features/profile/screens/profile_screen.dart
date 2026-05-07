// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/guest_home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  final _nameC = TextEditingController();
  final _branchC = TextEditingController();
  final _yearC = TextEditingController();
  final _bioC = TextEditingController();
  final _enrollC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _branchC.dispose();
    _yearC.dispose();
    _bioC.dispose();
    _enrollC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getCurrentUser(force: true),
      ApiService.getPersonalAnalytics(),
    ]);
    final user = results[0];
    final stats = results[1];
    if (mounted) {
      setState(() {
        _user = user;
        _stats = stats;
        _loading = false;
        if (user != null) {
          _nameC.text = user['name'] ?? '';
          _branchC.text = user['branch'] ?? '';
          _yearC.text = user['year'] ?? '';
          _bioC.text = user['bio'] ?? '';
          _enrollC.text = user['enrollment'] ?? '';
        }
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final filename = xfile.name;
    final url = await ApiService.uploadImageBytes(bytes, filename);
    if (url != null) {
      await ApiService.updateProfile(avatarUrl: url);
      _load();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.updateProfile(
        name: _nameC.text.trim(),
        branch: _branchC.text.trim(),
        year: _yearC.text.trim(),
        bio: _bioC.text.trim(),
        enrollment: _enrollC.text.trim(),
      );
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated ✓'),
            backgroundColor: ZynkColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const GuestHomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ZynkColors.primary),
      );
    }

    final user = _user ?? {};
    final name = user['name'] as String? ?? 'Student';
    final email = user['email'] as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;
    final branch = user['branch'] as String? ?? '';
    final year = user['year'] as String? ?? '';
    final college = user['college'] as String? ?? 'MAIT';
    final eventsCreated = _stats?['events_created'] ?? 0;
    final totalRegistered = _stats?['total_registered'] ?? 0;
    final attended = _stats?['attended'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        children: [
          // ── Avatar + name ────────────────────────────────────
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ZynkGradients.brand,
                    border: Border.all(
                      color: ZynkColors.primary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: avatarUrl != null
                      ? ClipOval(child: _buildAvatar(avatarUrl))
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: ZynkGradients.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F0A07), width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),

          if (branch.isNotEmpty || year.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (branch.isNotEmpty) branch,
                if (year.isNotEmpty) 'Year $year',
                college,
              ].join(' · '),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Stats row ────────────────────────────────────────
          Row(
            children: [
              _StatBox(value: '$eventsCreated', label: 'Created'),
              const SizedBox(width: 10),
              _StatBox(value: '$totalRegistered', label: 'Registered'),
              const SizedBox(width: 10),
              _StatBox(value: '$attended', label: 'Attended'),
            ],
          ),

          const SizedBox(height: 24),

          // ── Edit form ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Profile Info',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _editing = !_editing),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _editing
                              ? ZynkColors.primary.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _editing
                                ? ZynkColors.primary.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          _editing ? 'Cancel' : 'Edit',
                          style: TextStyle(
                            color: _editing
                                ? ZynkColors.primary
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProfileField(
                  label: 'Full name',
                  controller: _nameC,
                  enabled: _editing,
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                _ProfileField(
                  label: 'Branch / Dept',
                  controller: _branchC,
                  enabled: _editing,
                  icon: Icons.school_outlined,
                ),
                const SizedBox(height: 12),
                _ProfileField(
                  label: 'Year',
                  controller: _yearC,
                  enabled: _editing,
                  icon: Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 12),
                _ProfileField(
                  label: 'Enrollment no.',
                  controller: _enrollC,
                  enabled: _editing,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                _ProfileField(
                  label: 'Bio',
                  controller: _bioC,
                  enabled: _editing,
                  icon: Icons.info_outline_rounded,
                  maxLines: 3,
                ),
                if (_editing) ...[
                  const SizedBox(height: 18),
                  ZynkButton(
                    label: 'Save Changes',
                    icon: Icons.check_rounded,
                    onTap: _save,
                    isLoading: _saving,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Logout ────────────────────────────────────────────
          ZynkButton(
            label: 'Sign Out',
            icon: Icons.logout_rounded,
            outlined: true,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url) {
    if (url.startsWith('data:')) {
      try {
        final base64 = url.split(',').last;
        final bytes =
            Uri.parse(url).data?.contentAsBytes() ??
            // fallback:
            Uri.dataFromString(
              base64,
              mimeType: 'image/jpeg',
            ).data!.contentAsBytes();
        return Image.memory(bytes, width: 90, height: 90, fit: BoxFit.cover);
      } catch (_) {}
    }
    return Image.network(
      url,
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.person_rounded, color: Colors.white, size: 40),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (b) => ZynkGradients.brand.createShader(b),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final IconData icon;
  final int maxLines;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    maxLines: maxLines,
    style: TextStyle(
      color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.55),
      fontSize: 14,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      prefixIcon: Icon(
        icon,
        color: enabled
            ? ZynkColors.primary
            : Colors.white.withValues(alpha: 0.25),
        size: 18,
      ),
      filled: true,
      fillColor: enabled
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ZynkColors.primary.withValues(alpha: 0.4),
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ZynkColors.primary, width: 1.5),
      ),
    ),
  );
}
