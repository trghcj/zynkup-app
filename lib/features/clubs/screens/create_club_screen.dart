import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_toast.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  String _category = 'tech';
  bool _loading = false;

  Uint8List? _logoBytes;
  String? _logoName;

  Uint8List? _bannerBytes;
  String? _bannerName;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    setState(() {}); // Trigger rebuild for live preview & validation marks
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _descriptionController.removeListener(_onFormChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _logoBytes = bytes;
      _logoName = file.name.split('/').last.split('\\').last;
    });
  }

  Future<void> _pickBanner() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _bannerBytes = bytes;
      _bannerName = file.name.split('/').last.split('\\').last;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      String? logoUrl;
      String? bannerUrl;

      // Upload files
      if (_logoBytes != null && _logoName != null) {
        logoUrl = await ApiService.uploadImageBytes(_logoBytes!, _logoName!);
      }
      if (_bannerBytes != null && _bannerName != null) {
        bannerUrl = await ApiService.uploadImageBytes(_bannerBytes!, _bannerName!);
      }

      await ApiService.createClub(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
      );

      if (!mounted) return;
      ZToast.showSuccess(context, 'Club created', subtitle: 'Your campus community is live.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not create club. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ZynkColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 700;
    final isWide = width > 1050;

    final isNameValid = _nameController.text.trim().isNotEmpty;
    final isDescValid = _descriptionController.text.trim().isNotEmpty;

    const categories = [
      ('tech', Icons.computer_rounded),
      ('cultural', Icons.theater_comedy_rounded),
      ('sports', Icons.sports_basketball_rounded),
      ('workshop', Icons.build_rounded),
      ('seminar', Icons.record_voice_over_rounded),
    ];

    final formElements = <Widget>[
      const Text(
        'Start a New Club',
        style: TextStyle(
          color: ZynkColors.offWhite,
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Unite the campus around shared passions. Create custom logos and banner posters.',
        style: TextStyle(color: ZynkColors.darkMuted, fontSize: 15),
      ),
      const SizedBox(height: 32),

      // SECTION 01
      _buildSectionHeader('01', 'Club Information', isComplete: isNameValid && isDescValid),
      const SizedBox(height: 12),

      _buildLabel('Club Name'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _nameController,
        style: const TextStyle(color: ZynkColors.offWhite, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Enter your club name',
          hintStyle: const TextStyle(color: ZynkColors.darkMuted),
          filled: true,
          fillColor: ZynkColors.darkSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: isNameValid 
              ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20) 
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZynkColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZynkColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZynkColors.primary),
          ),
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Give your club a name' : null,
      ),
      const SizedBox(height: 20),

      _buildLabel('Club Description', isValid: isDescValid),
      const SizedBox(height: 8),
      TextFormField(
        controller: _descriptionController,
        maxLines: 5,
        style: const TextStyle(color: ZynkColors.offWhite, fontSize: 16, height: 1.4),
        decoration: InputDecoration(
          hintText: 'Tell students what your club is about...',
          hintStyle: const TextStyle(color: ZynkColors.darkMuted),
          filled: true,
          fillColor: ZynkColors.darkSurface,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZynkColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZynkColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZynkColors.primary),
          ),
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
      ),
      const SizedBox(height: 32),

      // SECTION 02
      _buildSectionHeader('02', 'Category', subtitle: 'Choose the category that best describes your club.', isComplete: true),
      const SizedBox(height: 24),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: categories.map((item) {
          final cat = item.$1;
          final icon = item.$2;
          final selected = _category == cat;
          return GestureDetector(
            onTap: () => setState(() => _category = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? ZynkColors.primary.withValues(alpha: 0.1) : ZynkColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? ZynkColors.primary : ZynkColors.darkBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: selected ? ZynkColors.primary : ZynkColors.darkMuted, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    cat[0].toUpperCase() + cat.substring(1),
                    style: TextStyle(
                      color: selected ? ZynkColors.primary : ZynkColors.darkMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 32),

      // SECTION 03
      _buildSectionHeader('03', 'Club Graphics', subtitle: 'Give your club a recognizable identity.', isComplete: _logoBytes != null || _bannerBytes != null),
      const SizedBox(height: 12),

      if (isDesktop)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _buildMediaPicker(
                title: 'Club Logo',
                icon: Icons.add_photo_alternate_rounded,
                bytes: _logoBytes,
                height: 160,
                onTap: _pickLogo,
                onClear: () => setState(() {
                  _logoBytes = null;
                  _logoName = null;
                }),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildMediaPicker(
                title: 'Club Banner',
                icon: Icons.view_headline_rounded,
                bytes: _bannerBytes,
                height: 160,
                onTap: _pickBanner,
                onClear: () => setState(() {
                  _bannerBytes = null;
                  _bannerName = null;
                }),
              ),
            ),
          ],
        )
      else ...[
        _buildMediaPicker(
          title: 'Club Logo',
          icon: Icons.add_photo_alternate_rounded,
          bytes: _logoBytes,
          height: 160,
          onTap: _pickLogo,
          onClear: () => setState(() {
            _logoBytes = null;
            _logoName = null;
          }),
        ),
        const SizedBox(height: 24),
        _buildMediaPicker(
          title: 'Club Banner',
          icon: Icons.view_headline_rounded,
          bytes: _bannerBytes,
          height: 160,
          onTap: _pickBanner,
          onClear: () => setState(() {
            _bannerBytes = null;
            _bannerName = null;
          }),
        ),
      ],

      const SizedBox(height: 32),

      // Primary Action
      Align(
        alignment: isDesktop ? Alignment.centerRight : Alignment.center,
        child: SizedBox(
          width: isDesktop ? 280 : double.infinity,
          child: ZynkButton(
            label: 'Found Club \u2192',
            icon: null,
            isLoading: _loading,
            onTap: _submit,
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Found a Club',
          style: TextStyle(color: ZynkColors.offWhite, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ZynkColors.offWhite),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: ZynkColors.offWhite, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ZynkBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 1200 : 960),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 24,
                    vertical: 32,
                  ),
                  children: [
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: formElements,
                            ),
                          ),
                          const SizedBox(width: 64),
                          Expanded(
                            flex: 10,
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              child: _buildLivePreview(),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      ...formElements,
                      if (isDesktop) ...[
                        const SizedBox(height: 48),
                        _buildLivePreview(),
                      ]
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreview() {
    final name = _nameController.text.trim();
    final desc = _descriptionController.text.trim();
    final catName = _category.isEmpty ? 'Category' : _category[0].toUpperCase() + _category.substring(1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_rounded, size: 16, color: ZynkColors.darkMuted),
              const SizedBox(width: 8),
              const Text(
                'Live Preview',
                style: TextStyle(color: ZynkColors.darkMuted, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Banner
          if (_bannerBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_bannerBytes!, height: 120, width: double.infinity, fit: BoxFit.cover),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: ZynkColors.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ZynkColors.darkBorder, style: BorderStyle.solid),
              ),
              child: const Center(child: Icon(Icons.view_headline_rounded, color: ZynkColors.darkMuted)),
            ),
          const SizedBox(height: 20),
          // Logo and Name
          Row(
            children: [
              if (_logoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_logoBytes!, height: 64, width: 64, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: ZynkColors.darkBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZynkColors.darkBorder),
                  ),
                  child: const Center(child: Icon(Icons.group, color: ZynkColors.darkMuted)),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Club Name' : name,
                      style: const TextStyle(color: ZynkColors.offWhite, fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$catName • Campus Club',
                      style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Description
          Text(
            desc.isEmpty ? 'Your club description will appear here...' : desc,
            style: TextStyle(
              color: desc.isEmpty ? ZynkColors.darkMuted : ZynkColors.offWhite, 
              fontSize: 14, 
              height: 1.4
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String number, String title, {String? subtitle, bool isComplete = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              number,
              style: TextStyle(
                color: isComplete ? ZynkColors.primary : ZynkColors.darkMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isComplete) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded, color: ZynkColors.primary, size: 14),
            ]
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(color: ZynkColors.offWhite, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 14)),
        ],
      ],
    );
  }

  Widget _buildLabel(String text, {bool isValid = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(color: ZynkColors.offWhite, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (isValid) ...[
          const SizedBox(width: 8),
          const Icon(Icons.check, color: Colors.green, size: 16),
        ]
      ],
    );
  }

  Widget _buildMediaPicker({
    required String title,
    required IconData icon,
    required Uint8List? bytes,
    required double height,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: ZynkColors.offWhite, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ZynkColors.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bytes != null ? ZynkColors.primary.withValues(alpha: 0.5) : ZynkColors.darkBorder),
            ),
            child: bytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.memory(bytes, fit: BoxFit.cover),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PREVIEW',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap to replace',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onClear,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: ZynkColors.darkMuted, size: 28),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload Image',
                        style: TextStyle(
                          color: ZynkColors.offWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
