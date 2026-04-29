// lib/features/user/screens/profile_setup_screen.dart
import 'dart:convert';
import 'dart:typed_data';
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

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _nameC     = TextEditingController();
  final _displayC  = TextEditingController();
  final _phoneC    = TextEditingController();
  final _enrollC   = TextEditingController();
  final _bioC      = TextEditingController();

  String? _branch, _year;
  String  _college   = 'MAIT';
  bool    _loading   = false;
  bool    _dataLoaded = false;
  bool    _isFirstSetup = false;

  Uint8List? _avatarBytes;
  String?    _avatarBase64;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;

  static const _branches = [
    'CSE','CSE (AI & ML)','CSE-AI','CSE (Data Science)',
    'IT','ECE','EEE','ME','CE','Other',
  ];
  static const _years    = ['1st Year','2nd Year','3rd Year','4th Year'];
  static const _colleges = ['MAIT','DTU','NSIT','IGDTUW','GGSIPU','IIT DELHI','Other'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadUser();
  }

  @override
  void dispose() {
    _nameC.dispose(); _displayC.dispose(); _phoneC.dispose();
    _enrollC.dispose(); _bioC.dispose(); _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await ApiService.getCurrentUser(force: true);
    if (u != null && mounted) {
      final existingAvatar = u['avatar_url'] as String?;
      setState(() {
        _nameC.text    = u['name']         ?? '';
        _displayC.text = u['display_name'] ?? '';
        _phoneC.text   = u['phone']        ?? '';
        _enrollC.text  = u['enrollment']   ?? '';
        _bioC.text     = u['bio']          ?? '';
        _college       = u['college']      ?? 'MAIT';
        final b        = u['branch'] as String?;
        _branch        = _branches.contains(b) ? b : null;
        final y        = u['year']   as String?;
        _year          = _years.contains(y)    ? y : null;
        _isFirstSetup  = (u['name'] == null || (u['name'] as String).isEmpty);

        // ✅ Decode and show existing avatar
        if (existingAvatar != null &&
            existingAvatar.isNotEmpty &&
            existingAvatar.startsWith('data:')) {
          try {
            _avatarBytes  = base64Decode(existingAvatar.split(',').last);
            _avatarBase64 = existingAvatar;
          } catch (_) {}
        }

        _dataLoaded = true;
      });
      _animController.forward();
    } else {
      if (mounted) { setState(() => _dataLoaded = true); _animController.forward(); }
    }
  }

  double get _completionScore {
    int s = 0;
    if (_nameC.text.isNotEmpty)    s++;
    if (_displayC.text.isNotEmpty) s++;
    if (_phoneC.text.isNotEmpty)   s++;
    if (_enrollC.text.isNotEmpty)  s++;
    if (_branch != null)            s++;
    if (_year   != null)            s++;
    if (_bioC.text.isNotEmpty)     s++;
    if (_avatarBytes != null)       s++;
    return s / 8;
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400, maxHeight: 400, imageQuality: 80,
      );
      if (picked == null) return;
      final bytes      = await picked.readAsBytes();
      final base64Str  = base64Encode(bytes);
      final ext        = picked.name.split('.').last.toLowerCase();
      final mime       = ext == 'png' ? 'image/png' : 'image/jpeg';
      setState(() {
        _avatarBytes  = bytes;
        _avatarBase64 = 'data:$mime;base64,$base64Str';
      });
    } catch (_) { _snack('Could not pick image', ZynkColors.error); }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final ok = await ApiService.createProfile(
        name:        _nameC.text.trim(),
        displayName: _displayC.text.trim().isEmpty ? null : _displayC.text.trim(),
        phone:       _phoneC.text.trim().isEmpty   ? null : _phoneC.text.trim(),
        branch:      _branch, year: _year,
        enrollment:  _enrollC.text.trim().isEmpty  ? null : _enrollC.text.trim(),
        college:     _college,
        bio:         _bioC.text.trim().isEmpty      ? null : _bioC.text.trim(),
        avatarUrl:   _avatarBase64,
      );
      if (!mounted) return;
      if (!ok) { _snack('Failed to save profile', ZynkColors.error);
       Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const UserHomeScreen()),
          (_) => false,
  );
       return; 
       }
      _snack('Profile saved! 🎉', ZynkColors.success);
      final user = await ApiService.getCurrentUser(force: true);
      if (!mounted) return;
      if (user?['role'] == 'admin') {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const AdminHomeScreen()), (_) => false);
      } else {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const UserHomeScreen()), (_) => false);
      }
    } on ApiException catch (e) {
      _snack(e.message, ZynkColors.error);
    } catch (_) { _snack('Something went wrong', ZynkColors.error);
     Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const UserHomeScreen()),
    (_) => false,
  );
  }
    finally     { if (mounted) setState(() => _loading = false); }
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (!_dataLoaded) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: ZynkColors.primary)));
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, height: 260,
            child: Container(decoration: const BoxDecoration(gradient: ZynkGradients.brand))),
          Positioned(top: -40, right: -40,
            child: Container(width: 180, height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06)))),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context)),
                    const Spacer(),
                    TextButton(
                      onPressed: _loading ? null : _save,
                      child: const Text('Save', style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
                  ]),
                ),

                // Avatar
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(alignment: Alignment.bottomRight, children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12)],
                      ),
                      child: ClipOval(
                        child: _avatarBytes != null
                            ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                            : Container(color: Colors.white.withOpacity(0.15),
                                child: const Icon(Icons.person_rounded, color: Colors.white, size: 44)),
                      ),
                    ),
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: ZynkColors.accent, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13)),
                  ]),
                ),

                const SizedBox(height: 8),
                const Text('Your Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_isFirstSetup ? 'Tell us a bit about yourself' : 'Update your details',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 14),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Profile completion',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('${(_completionScore * 100).round()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _completionScore,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 12),

                // Form area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: dark ? ZynkColors.darkBg : ZynkColors.lightBg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        children: [
                          _sectionHeader('Personal Info', Icons.person_rounded, dark),
                          const SizedBox(height: 12),
                          _field(_nameC, 'Full Name *', Icons.badge_rounded, required: true, dark: dark),
                          const SizedBox(height: 10),
                          _field(_displayC, 'Display Name (nickname)', Icons.face_rounded, dark: dark),
                          const SizedBox(height: 10),
                          _field(_phoneC, 'Phone Number', Icons.phone_rounded, type: TextInputType.phone, dark: dark),
                          const SizedBox(height: 24),

                          _sectionHeader('Academic Details', Icons.school_rounded, dark),
                          const SizedBox(height: 12),
                          _dropdown(label: 'College', icon: Icons.account_balance_rounded,
                              value: _college, items: _colleges,
                              onChanged: (v) => setState(() => _college = v!), dark: dark),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _dropdown(label: 'Branch', icon: Icons.computer_rounded,
                                value: _branch, items: _branches,
                                onChanged: (v) => setState(() => _branch = v), dark: dark, nullable: true)),
                            const SizedBox(width: 10),
                            Expanded(child: _dropdown(label: 'Year', icon: Icons.calendar_today_rounded,
                                value: _year, items: _years,
                                onChanged: (v) => setState(() => _year = v), dark: dark, nullable: true)),
                          ]),
                          const SizedBox(height: 10),
                          _field(_enrollC, 'Enrollment / Student ID', Icons.numbers_rounded, dark: dark),
                          const SizedBox(height: 24),

                          _sectionHeader('Bio', Icons.edit_note_rounded, dark),
                          const SizedBox(height: 12),
                          _field(_bioC, 'Tell us about yourself...', Icons.notes_rounded, maxLines: 3, dark: dark),
                          const SizedBox(height: 28),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ZynkColors.primary.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ZynkColors.primary.withOpacity(0.2))),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.shield_outlined, color: ZynkColors.primary, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(
                                'Your role (Student / Organizer) will be assigned by an admin.',
                                style: TextStyle(fontSize: 12, height: 1.5,
                                    color: dark ? ZynkColors.darkText.withOpacity(0.7)
                                        : ZynkColors.lightText.withOpacity(0.7)))),
                            ]),
                          ),

                          const SizedBox(height: 24),

ZynkButton(
  label: _isFirstSetup ? 'Complete Profile' : 'Save Changes',
  icon: _isFirstSetup ? Icons.arrow_forward_rounded : Icons.save_rounded,
  isLoading: _loading,
  onTap: _save,
),

const SizedBox(height: 10),

TextButton(
  onPressed: () {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UserHomeScreen()),
      (_) => false,
    );
  },
  child: const Text(
    "Skip for now",
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  ),
),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  } 

  Widget _sectionHeader(String label, IconData icon, bool dark) => Row(children: [
    Container(width: 32, height: 32,
        decoration: BoxDecoration(color: ZynkColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: ZynkColors.primary, size: 16)),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
        color: dark ? ZynkColors.darkText : ZynkColors.lightText)),
  ]);

  Widget _field(TextEditingController c, String label, IconData icon,
      {int maxLines = 1, TextInputType? type, bool required = false, required bool dark}) =>
      TextFormField(controller: c, maxLines: maxLines, keyboardType: type,
          onChanged: (_) => setState(() {}),
          validator: required ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)));

  Widget _dropdown({required String label, required IconData icon, required String? value,
    required List<String> items, required ValueChanged<String?> onChanged,
    required bool dark, bool nullable = false}) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (v) { onChanged(v); setState(() {}); });
}