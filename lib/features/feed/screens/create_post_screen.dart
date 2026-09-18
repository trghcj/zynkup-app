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
  final _linkUrlController = TextEditingController();
  final _linkTitleController = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = false;
  bool _showLinkInput = false;
  String? _detectedLinkType;

  Uint8List? _photoBytes;
  String? _photoName;

  Uint8List? _bannerBytes;
  String? _bannerName;

  @override
  void dispose() {
    _contentController.dispose();
    _linkUrlController.dispose();
    _linkTitleController.dispose();
    super.dispose();
  }

  void _onLinkChanged(String val) {
    final trimmed = val.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() => _detectedLinkType = null);
      return;
    }
    if (trimmed.contains('youtube.com') || trimmed.contains('youtu.be')) {
      setState(() => _detectedLinkType = 'youtube');
    } else if (trimmed.contains('instagram.com') || trimmed.contains('instagr.am')) {
      setState(() => _detectedLinkType = 'instagram');
    } else {
      setState(() => _detectedLinkType = 'general');
    }
  }

  String? _getYouTubeThumbnail(String url) {
    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    final id = match?.group(1);
    if (id != null) {
      return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
    }
    return null;
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

      final linkUrl = _linkUrlController.text.trim();
      final linkTitle = _linkTitleController.text.trim();

      // 3. Create feed post
      await ApiService.createFeedPost(
        content: _contentController.text.trim(),
        imageUrl: photoUrl,
        bannerUrl: bannerUrl,
        linkUrl: linkUrl.isNotEmpty ? linkUrl : null,
        linkTitle: linkTitle.isNotEmpty ? linkTitle : null,
        linkType: linkUrl.isNotEmpty ? _detectedLinkType : null,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                     Text(
                      'What\'s buzzing on campus?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                     Text(
                      'Share an update, moment, or announcement with the campus.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Content editor
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(ZynkRadius.lg),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                        controller: _contentController,
                        maxLines: 5,
                        maxLength: 600,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write your update here...',
                          hintStyle: TextStyle(color: ZynkColors.darkMuted),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          counterStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 11),
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
                        color: ZynkColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Compact side-by-side media uploaders
                    Row(
                      children: [
                        Expanded(
                          child: _buildMediaPicker(
                            title: 'Add Photo',
                            subtitle: 'Standard image',
                            icon: Icons.add_photo_alternate_rounded,
                            bytes: _photoBytes,
                            onTap: _pickPhoto,
                            onClear: () => setState(() {
                              _photoBytes = null;
                              _photoName = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMediaPicker(
                            title: 'Add Banner',
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
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Embedded Link (Optional)',
                          style: TextStyle(
                            color: ZynkColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (!_showLinkInput && _linkUrlController.text.isEmpty)
                          TextButton.icon(
                            onPressed: () => setState(() => _showLinkInput = true),
                            icon: const Icon(Icons.add_link_rounded, size: 18),
                            label: const Text('Add Link'),
                          ),
                      ],
                    ),
                    if (_showLinkInput || _linkUrlController.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(ZynkRadius.lg),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _detectedLinkType == 'youtube'
                                      ? Icons.play_circle_fill_rounded
                                      : _detectedLinkType == 'instagram'
                                          ? Icons.camera_alt_rounded
                                          : Icons.link_rounded,
                                  color: _detectedLinkType == 'youtube'
                                      ? Colors.red
                                      : _detectedLinkType == 'instagram'
                                          ? Colors.purpleAccent
                                          : ZynkColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _detectedLinkType == 'youtube'
                                        ? 'YouTube Video Link'
                                        : _detectedLinkType == 'instagram'
                                            ? 'Instagram Post / Reel Link'
                                            : 'Web Link',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _linkUrlController.clear();
                                      _linkTitleController.clear();
                                      _detectedLinkType = null;
                                      _showLinkInput = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _linkUrlController,
                              onChanged: _onLinkChanged,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'https://youtube.com/... or instagram.com/...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? ZynkColors.darkMuted
                                      : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark
                                    ? ZynkColors.darkSurface2
                                    : const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _linkTitleController,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Link Title or Label (Optional)',
                                hintStyle: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? ZynkColors.darkMuted
                                      : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark
                                    ? ZynkColors.darkSurface2
                                    : const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            if (_detectedLinkType == 'youtube' && _getYouTubeThumbnail(_linkUrlController.text) != null) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.network(
                                      _getYouTubeThumbnail(_linkUrlController.text)!,
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(ZynkRadius.md),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
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
                  Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), size: 24),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
