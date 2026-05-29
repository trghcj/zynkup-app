import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';

class CreatePostScreen extends StatefulWidget {
  final int? clubId;
  const CreatePostScreen({super.key, this.clubId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = false;
  Uint8List? _photoBytes;
  String? _photoName;

  Uint8List? _bannerBytes;
  String? _bannerName;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoName = file.name.split('/').last.split('\\').last;
    });
  }

  Future<void> _pickBanner() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
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
      String? photoUrl;
      String? bannerUrl;

      // 1. Upload photo if present
      if (_photoBytes != null && _photoName != null) {
        photoUrl = await ApiService.uploadImageBytes(_photoBytes!, _photoName!);
      }

      // 2. Upload banner if present
      if (_bannerBytes != null && _bannerName != null) {
        bannerUrl = await ApiService.uploadImageBytes(_bannerBytes!, _bannerName!);
      }

      // 3. Create feed post
      await ApiService.createFeedPost(
        content: _contentController.text.trim(),
        imageUrl: photoUrl,
        bannerUrl: bannerUrl,
        clubId: widget.clubId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update posted successfully!')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not post update. Please try again.');
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
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Share an Update'),
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
                  'What\'s buzzing on campus?',
                  style: TextStyle(
                    color: ZynkColors.offWhite,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share an update, moment, or announcement with the campus.',
                  style: TextStyle(
                    color: ZynkColors.darkMuted.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),

                // Content editor
                Container(
                  decoration: BoxDecoration(
                    color: ZynkColors.darkSurface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(ZynkRadius.lg),
                    border: Border.all(color: ZynkColors.darkBorder),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _contentController,
                    maxLines: 5,
                    maxLength: 600,
                    style: const TextStyle(
                      color: ZynkColors.offWhite,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Write your update here...',
                      hintStyle: TextStyle(color: ZynkColors.darkMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      counterStyle: TextStyle(color: ZynkColors.darkMuted, fontSize: 11),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Share a bit of text with the campus'
                        : null,
                  ),
                ),
                const SizedBox(height: 24),

                // Uploads headers
                const Text(
                  'Media Attachments (Optional)',
                  style: TextStyle(
                    color: ZynkColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),

                // Photo upload card
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: ZynkColors.darkSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(ZynkRadius.md),
                      border: Border.all(
                        color: ZynkColors.darkBorder,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _photoBytes != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                                child: Image.memory(_photoBytes!, fit: BoxFit.cover),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                                ),
                              ),
                              const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Change Photo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => setState(() {
                                    _photoBytes = null;
                                    _photoName = null;
                                  }),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: ZynkColors.darkMuted,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add Photo',
                                style: TextStyle(
                                  color: ZynkColors.offWhite,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'A standard feed image attachment',
                                style: TextStyle(
                                  color: ZynkColors.darkMuted.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Banner upload card
                GestureDetector(
                  onTap: _pickBanner,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: ZynkColors.darkSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(ZynkRadius.md),
                      border: Border.all(
                        color: ZynkColors.darkBorder,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _bannerBytes != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                                child: Image.memory(_bannerBytes!, fit: BoxFit.cover),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                                ),
                              ),
                              const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.crop_original_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Change Banner',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => setState(() {
                                    _bannerBytes = null;
                                    _bannerName = null;
                                  }),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.view_headline_rounded,
                                color: ZynkColors.darkMuted,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add Banner',
                                style: TextStyle(
                                  color: ZynkColors.offWhite,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'A premium banner placed at the header',
                                style: TextStyle(
                                  color: ZynkColors.darkMuted.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 48),

                // Publish Button
                ZynkButton(
                  label: 'Publish Post',
                  icon: Icons.send_rounded,
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
