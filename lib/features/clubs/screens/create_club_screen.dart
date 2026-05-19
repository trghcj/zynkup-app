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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Start a New Club',
                  style: TextStyle(
                    color: ZynkColors.offWhite,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unite the campus around shared passions. Create custom logos and banner posters.',
                  style: TextStyle(
                    color: ZynkColors.darkMuted.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Name input
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(
                    color: ZynkColors.offWhite,
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
                  style: const TextStyle(color: ZynkColors.offWhite, fontSize: 15),
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
                    color: ZynkColors.gold,
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
                          gradient: selected ? ZynkGradients.forCategory(cat) : null,
                          color: selected ? null : ZynkColors.darkSurface,
                          borderRadius: BorderRadius.circular(ZynkRadius.pill),
                          border: Border.all(
                            color: selected ? Colors.transparent : ZynkColors.darkBorder,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: ZynkColors.forCategory(cat).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: selected ? Colors.white : ZynkColors.darkMuted, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              cat[0].toUpperCase() + cat.substring(1),
                              style: TextStyle(
                                color: selected ? Colors.white : ZynkColors.darkMuted,
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
                    color: ZynkColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Dual column uploads: Logo & Banner
                Row(
                  children: [
                    // Logo Picker (Square/Circular look)
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Club Logo',
                            style: TextStyle(color: ZynkColors.darkMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickLogo,
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ZynkColors.darkSurface.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(ZynkRadius.md),
                                border: Border.all(color: ZynkColors.darkBorder),
                              ),
                              child: _logoBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.memory(_logoBytes!, fit: BoxFit.cover),
                                          Container(color: Colors.black26),
                                          const Center(
                                            child: Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_rounded, color: ZynkColors.darkMuted, size: 24),
                                        SizedBox(height: 4),
                                        Text('Upload Logo', style: TextStyle(color: ZynkColors.offWhite, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Banner Picker (Wide look)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Club Banner',
                            style: TextStyle(color: ZynkColors.darkMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickBanner,
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: ZynkColors.darkSurface.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(ZynkRadius.md),
                                border: Border.all(color: ZynkColors.darkBorder),
                              ),
                              child: _bannerBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.memory(_bannerBytes!, fit: BoxFit.cover),
                                          Container(color: Colors.black26),
                                          const Center(
                                            child: Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.crop_original_rounded, color: ZynkColors.darkMuted, size: 24),
                                        SizedBox(height: 4),
                                        Text('Upload Banner', style: TextStyle(color: ZynkColors.offWhite, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
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
    );
  }
}
