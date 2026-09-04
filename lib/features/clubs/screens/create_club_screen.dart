import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
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
  void dispose() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Club created successfully!')),
      );
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
    const categories = [
      ('tech', Icons.computer_rounded),
      ('cultural', Icons.theater_comedy_rounded),
      ('sports', Icons.sports_basketball_rounded),
      ('workshop', Icons.build_rounded),
      ('seminar', Icons.record_voice_over_rounded),
    ];

    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Found a Club'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ZynkBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Start a New Club',
                      style: TextStyle(
                        color: ZynkColors.darkText,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unite the campus around shared passions. Create custom logos and banner posters.',
                      style: TextStyle(
                        color: ZynkColors.darkMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name input
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(
                        color: ZynkColors.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Club Name',
                        hintText: 'e.g. Zynk Robotics Club',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Give your club a name' : null,
                    ),
                    const SizedBox(height: 24),

                    // Description input
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: ZynkColors.darkText, fontSize: 15),
                      decoration: const InputDecoration(
                        labelText: 'Club Description',
                        hintText: 'What is this club\'s goal? What kinds of events will you hold?',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Description is required'
                          : null,
                    ),
                    const SizedBox(height: 28),

                    // Category chooser
                    const Text(
                      'Select Category',
                      style: TextStyle(
                        color: ZynkColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: categories.map((item) {
                        final cat = item.$1;
                        final icon = item.$2;
                        final selected = _category == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _category = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? ZynkColors.primary.withValues(alpha: 0.1) : ZynkColors.darkSurface,
                              borderRadius: BorderRadius.circular(ZynkRadius.pill),
                              border: Border.all(
                                color: selected ? ZynkColors.primary : ZynkColors.darkBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, color: selected ? ZynkColors.primary : ZynkColors.darkMuted, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  cat[0].toUpperCase() + cat.substring(1),
                                  style: TextStyle(
                                    color: selected ? ZynkColors.primary : ZynkColors.darkMuted,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Media upload headers
                    const Text(
                      'Club Graphics (Optional)',
                      style: TextStyle(
                        color: ZynkColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dual column uploads: Logo & Banner
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildMediaPicker(
                            title: 'Club Logo',
                            subtitle: 'Square upload',
                            icon: Icons.add_photo_alternate_rounded,
                            bytes: _logoBytes,
                            onTap: _pickLogo,
                            onClear: () => setState(() {
                              _logoBytes = null;
                              _logoName = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _buildMediaPicker(
                            title: 'Club Banner',
                            subtitle: 'Premium header',
                            icon: Icons.view_headline_rounded,
                            bytes: _bannerBytes,
                            onTap: _pickBanner,
                            onClear: () => setState(() {
                              _bannerBytes = null;
                              _bannerName = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Found Button
                    ZynkButton(
                      label: 'Found Club',
                      icon: Icons.rocket_launch_rounded,
                      isLoading: _loading,
                      onTap: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPicker({
    required String title,
    required String subtitle,
    required IconData icon,
    required Uint8List? bytes,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: ZynkColors.darkMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: ZynkColors.darkSurface,
              borderRadius: BorderRadius.circular(ZynkRadius.md),
              border: Border.all(
                color: ZynkColors.darkBorder,
              ),
            ),
            child: bytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                        child: Image.memory(bytes, fit: BoxFit.cover),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                        ),
                      ),
                      const Center(
                        child: Icon(Icons.edit, color: Colors.white, size: 24),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onClear,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: ZynkColors.darkMuted, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          color: ZynkColors.darkText,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: ZynkColors.darkMuted,
                          fontSize: 10,
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
