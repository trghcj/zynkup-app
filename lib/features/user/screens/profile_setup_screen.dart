// lib/features/user/screens/profile_setup_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/admin/screens/admin_home_screen.dart';
import 'package:zynkup/features/user/screens/user_home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameC      = TextEditingController();
  final _displayC   = TextEditingController();
  final _phoneC     = TextEditingController();
  final _enrollC    = TextEditingController();
  final _bioC       = TextEditingController();

  String? _branch, _year;
  String  _college = 'MAIT';
  bool    _loading = false, _dataLoaded = false;

  // Profile picture
  Uint8List? _avatarBytes;   // for display
  String?    _avatarBase64;  // sent to backend as data URL

  static const _branches = [
    'CSE', 'CSE (AI & ML)', 'CSE (Data Science)',
    'IT', 'ECE', 'EEE', 'ME', 'CE', 'Other',
  ];
  static const _years = [
    '1st Year', '2nd Year', '3rd Year', '4th Year'
  ];
  static const _colleges = [
    'MAIT', 'DTU', 'NSIT', 'IGDTUW', 'GGSIPU', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await ApiService.getCurrentUser();
    if (u != null && mounted) {
      setState(() {
        _nameC.text    = u["name"]         ?? '';
        _displayC.text = u["display_name"] ?? '';
        _phoneC.text   = u["phone"]        ?? '';
        _enrollC.text  = u["enrollment"]   ?? '';
        _bioC.text     = u["bio"]          ?? '';
        _college       = u["college"]      ?? 'MAIT';
        final b = u["branch"] as String?;
        _branch = _branches.contains(b) ? b : null;
        final y = u["year"] as String?;
        _year   = _years.contains(y) ? y : null;
        _dataLoaded = true;
      });
    } else {
      if (mounted) setState(() => _dataLoaded = true);
    }
  }

  // ── Pick profile picture ──────────────────────────────────────────────────
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64Str = base64Encode(bytes);
      final ext = picked.name.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

      setState(() {
        _avatarBytes  = bytes;
        _avatarBase64 = 'data:$mime;base64,$base64Str';
      });
    } catch (e) {
      _snack('Could not pick image. Try again.', ZynkColors.error);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final success = await ApiService.createProfile(
        name:        _nameC.text.trim(),
        displayName: _displayC.text.trim().isEmpty ? null : _displayC.text.trim(),
        phone:       _phoneC.text.trim().isEmpty   ? null : _phoneC.text.trim(),
        branch:      _branch,
        year:        _year,
        enrollment:  _enrollC.text.trim().isEmpty  ? null : _enrollC.text.trim(),
        college:     _college,
        bio:         _bioC.text.trim().isEmpty      ? null : _bioC.text.trim(),
        avatarUrl:   _avatarBase64,
      );
      if (!mounted) return;
      if (!success) { _snack('Failed to save. Try again.', ZynkColors.error); return; }
      _snack('Profile saved! 🎉', ZynkColors.success);
      final u = await ApiService.getCurrentUser(force: true);
      if (u?["role"] == "admin") {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
            (_) => false);
      } else {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
            (_) => false);
      }
    } on ApiException catch (e) {
      _snack(e.message, ZynkColors.error);
    } catch (_) {
      _snack('Something went wrong.', ZynkColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _nameC.dispose(); _displayC.dispose(); _phoneC.dispose();
    _enrollC.dispose(); _bioC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!_dataLoaded) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: ZynkColors.primary)));
    }

    return Scaffold(
      body: Stack(children: [
        // ── Brand header ──────────────────────────────────
        Container(
          height: 230,
          decoration: const BoxDecoration(gradient: ZynkGradients.brand),
          child: Stack(children: [
            Positioned(top: -30, right: -30,
              child: Container(width: 160, height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07)))),
            Positioned(bottom: -20, left: 40,
              child: Container(width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05)))),
          ]),
        ),

        SafeArea(child: Column(children: [
          // ── Back button ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 15),
                ),
              ),
            ]),
          ),

          // ── Avatar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: [
              // Tappable avatar
              GestureDetector(
                onTap: _pickImage,
                child: Stack(alignment: Alignment.bottomRight, children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      gradient: _avatarBytes == null ? ZynkGradients.brand : null,
                    ),
                    child: ClipOval(
                      child: _avatarBytes != null
                          ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                          : const Icon(Icons.person_rounded,
                              color: Colors.white, size: 44),
                    ),
                  ),
                  // Camera button
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: ZynkGradients.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 13),
                  ),
                ]),
              ),

              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickImage,
                child: const Text('Tap to change photo',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white70)),
              ),

              const SizedBox(height: 4),
              const Text('Your Profile',
                  style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
          ),

          // ── Form ─────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: dark ? ZynkColors.darkBg : ZynkColors.lightBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Form(key: _formKey, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _Section(label: 'Personal Info', icon: Icons.person_rounded),
                    const SizedBox(height: 14),

                    _Field(c: _nameC, label: 'Full Name *', icon: Icons.badge_rounded,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Full name is required' : null),
                    const SizedBox(height: 12),
                    _Field(c: _displayC, label: 'Display Name (nickname)',
                        icon: Icons.face_rounded, hint: 'What should we call you?'),
                    const SizedBox(height: 12),
                    _Field(c: _phoneC, label: 'Phone Number',
                        icon: Icons.phone_rounded,
                        hint: '+91 XXXXX XXXXX',
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          if (v.replaceAll(RegExp(r'\D'), '').length < 10)
                            return 'Enter a valid phone number';
                          return null;
                        }),

                    const SizedBox(height: 24),
                    _Section(label: 'Academic Details', icon: Icons.school_rounded),
                    const SizedBox(height: 14),

                    _Drop(label: 'College', icon: Icons.account_balance_rounded,
                        value: _colleges.contains(_college) ? _college : null,
                        items: _colleges,
                        onChanged: (v) => setState(() => _college = v ?? 'MAIT')),
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(child: _Drop(label: 'Branch', icon: Icons.code_rounded,
                          value: _branch, items: _branches,
                          onChanged: (v) => setState(() => _branch = v))),
                      const SizedBox(width: 12),
                      Expanded(child: _Drop(label: 'Year',
                          icon: Icons.calendar_today_rounded,
                          value: _year, items: _years,
                          onChanged: (v) => setState(() => _year = v))),
                    ]),
                    const SizedBox(height: 12),
                    _Field(c: _enrollC, label: 'Enrollment / Student ID',
                        icon: Icons.numbers_rounded, hint: 'e.g. 04819803821'),

                    const SizedBox(height: 24),
                    _Section(label: 'About You', icon: Icons.auto_awesome_rounded),
                    const SizedBox(height: 14),

                    _Field(c: _bioC, label: 'Bio', icon: Icons.edit_note_rounded,
                        hint: 'A short intro about yourself…', maxLines: 3),
                    const SizedBox(height: 12),

                    // Role info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ZynkColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: ZynkColors.primary.withOpacity(0.2)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline_rounded,
                            color: ZynkColors.primary, size: 18),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                          'Your role (Student / Organizer) will be assigned by an admin.',
                          style: TextStyle(color: ZynkColors.primary,
                              fontSize: 12, height: 1.4),
                        )),
                      ]),
                    ),

                    const SizedBox(height: 28),

                    ZynkButton(
                      label: 'Save & Continue',
                      icon: Icons.arrow_forward_rounded,
                      onTap: _save,
                      isLoading: _loading,
                    ),

                    const SizedBox(height: 12),

                    Center(child: TextButton(
                      onPressed: _loading ? null : () async {
                        final u = await ApiService.getCurrentUser();
                        if (!mounted) return;
                        if (u?["role"] == "admin") {
                          Navigator.pushAndRemoveUntil(context,
                              MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
                              (_) => false);
                        } else {
                          Navigator.pushAndRemoveUntil(context,
                              MaterialPageRoute(builder: (_) => const UserHomeScreen()),
                              (_) => false);
                        }
                      },
                      child: Text('Skip for now',
                          style: TextStyle(
                            color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                            fontSize: 13,
                          )),
                    )),
                  ],
                )),
              ),
            ),
          ),
        ])),
      ]),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label; final IconData icon;
  const _Section({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 30, height: 30,
          decoration: BoxDecoration(gradient: ZynkGradients.brand,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 15)),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: ZynkColors.primary,
          fontWeight: FontWeight.w800, fontSize: 15)),
    ]);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController c;
  final String label; final IconData icon;
  final String? hint; final TextInputType? keyboardType;
  final String? Function(String?)? validator; final int maxLines;
  const _Field({required this.c, required this.label, required this.icon,
    this.hint, this.keyboardType, this.validator, this.maxLines = 1});
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: c, keyboardType: keyboardType,
    maxLines: maxLines, validator: validator,
    decoration: InputDecoration(labelText: label, hintText: hint,
        prefixIcon: Icon(icon)));
}

class _Drop extends StatelessWidget {
  final String label; final IconData icon;
  final String? value; final List<String> items;
  final void Function(String?) onChanged;
  const _Drop({required this.label, required this.icon, required this.value,
    required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value, isExpanded: true,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    items: items.map((e) => DropdownMenuItem(value: e,
        child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
    onChanged: onChanged);
}