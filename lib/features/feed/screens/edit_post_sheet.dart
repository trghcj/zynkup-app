import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class EditPostSheet extends StatefulWidget {
  final int postId;
  final String initialContent;
  final String? initialImageUrl;
  final String? initialBannerUrl;
  final String? initialLinkUrl;
  final String? initialLinkTitle;
  final String? initialLinkType;

  const EditPostSheet({
    super.key,
    required this.postId,
    required this.initialContent,
    this.initialImageUrl,
    this.initialBannerUrl,
    this.initialLinkUrl,
    this.initialLinkTitle,
    this.initialLinkType,
  });

  @override
  State<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<EditPostSheet> {
  final _picker = ImagePicker();
  late TextEditingController _controller;
  late TextEditingController _linkUrlController;
  late TextEditingController _linkTitleController;
  bool _saving = false;

  String? _currentPhotoUrl;
  Uint8List? _newPhotoBytes;
  String? _newPhotoName;
  bool _photoRemoved = false;

  String? _currentBannerUrl;
  Uint8List? _newBannerBytes;
  String? _newBannerName;
  bool _bannerRemoved = false;

  String? _detectedLinkType;
  bool _linkRemoved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _currentPhotoUrl = widget.initialImageUrl;
    _currentBannerUrl = widget.initialBannerUrl;
    _linkUrlController = TextEditingController(text: widget.initialLinkUrl ?? '');
    _linkTitleController = TextEditingController(text: widget.initialLinkTitle ?? '');
    _detectedLinkType = widget.initialLinkType;
  }

  @override
  void dispose() {
    _controller.dispose();
    _linkUrlController.dispose();
    _linkTitleController.dispose();
    super.dispose();
  }

  void _onLinkChanged(String val) {
    final trimmed = val.trim().toLowerCase();
    _linkRemoved = false;
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

  void _clearLink() {
    setState(() {
      _linkUrlController.clear();
      _linkTitleController.clear();
      _detectedLinkType = null;
      _linkRemoved = true;
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _newPhotoBytes = bytes;
        _newPhotoName = file.name.split('/').last.split('\\').last;
        _photoRemoved = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick photo: $e')),
        );
      }
    }
  }

  Future<void> _pickBanner() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _newBannerBytes = bytes;
        _newBannerName = file.name.split('/').last.split('\\').last;
        _bannerRemoved = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick banner: $e')),
        );
      }
    }
  }

  void _clearPhoto() {
    setState(() {
      _newPhotoBytes = null;
      _newPhotoName = null;
      _photoRemoved = true;
      _currentPhotoUrl = null;
    });
  }

  void _clearBanner() {
    setState(() {
      _newBannerBytes = null;
      _newBannerName = null;
      _bannerRemoved = true;
      _currentBannerUrl = null;
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _saving = true);
    try {
      String? finalPhotoUrl;
      if (_newPhotoBytes != null && _newPhotoName != null) {
        finalPhotoUrl = await ApiService.uploadImageBytes(_newPhotoBytes!, _newPhotoName!);
      } else if (_photoRemoved) {
        finalPhotoUrl = ""; // empty string clears on backend
      } else {
        finalPhotoUrl = _currentPhotoUrl;
      }

      String? finalBannerUrl;
      if (_newBannerBytes != null && _newBannerName != null) {
        finalBannerUrl = await ApiService.uploadImageBytes(_newBannerBytes!, _newBannerName!);
      } else if (_bannerRemoved) {
        finalBannerUrl = ""; // empty string clears on backend
      } else {
        finalBannerUrl = _currentBannerUrl;
      }

      String? finalLinkUrl;
      String? finalLinkTitle;
      String? finalLinkType;
      if (_linkRemoved) {
        finalLinkUrl = ""; // empty string clears on backend
        finalLinkTitle = "";
        finalLinkType = "";
      } else if (_linkUrlController.text.trim().isNotEmpty) {
        finalLinkUrl = _linkUrlController.text.trim();
        finalLinkTitle = _linkTitleController.text.trim().isEmpty ? null : _linkTitleController.text.trim();
        finalLinkType = _detectedLinkType;
      }

      final res = await ApiService.editFeedPost(
        widget.postId,
        content: text,
        imageUrl: finalPhotoUrl,
        bannerUrl: finalBannerUrl,
        linkUrl: finalLinkUrl,
        linkTitle: finalLinkTitle,
        linkType: finalLinkType,
      );
      if (!mounted) return;
      setState(() => _saving = false);

      if (res != null) {
        Navigator.pop(context, res); // Return the updated post
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update post.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating post: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ZynkColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: ZynkColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Edit Post',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Content text field
              TextField(
                controller: _controller,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Update your post...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZynkColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Media Section Header
              Text(
                'Media Attachments',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Media Slots (Side-by-Side: Photo & Banner)
              Row(
                children: [
                  Expanded(
                    child: _buildMediaSlot(
                      title: 'Photo',
                      subtitle: 'Standard image',
                      icon: Icons.add_photo_alternate_rounded,
                      newBytes: _newPhotoBytes,
                      existingUrl: _currentPhotoUrl,
                      isRemoved: _photoRemoved,
                      onTap: _pickPhoto,
                      onClear: _clearPhoto,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMediaSlot(
                      title: 'Banner',
                      subtitle: 'Header banner',
                      icon: Icons.view_headline_rounded,
                      newBytes: _newBannerBytes,
                      existingUrl: _currentBannerUrl,
                      isRemoved: _bannerRemoved,
                      onTap: _pickBanner,
                      onClear: _clearBanner,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Embedded Link Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attached Link',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_linkUrlController.text.isNotEmpty || _detectedLinkType != null)
                    InkWell(
                      onTap: _clearLink,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Remove Link',
                          style: TextStyle(
                            color: ZynkColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _linkUrlController,
                onChanged: _onLinkChanged,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/... or https://instagram.com/...',
                  hintStyle: TextStyle(color: isDark ? ZynkColors.darkMuted : const Color(0xFF94A3B8), fontSize: 12),
                  prefixIcon: Icon(
                    _detectedLinkType == 'youtube'
                        ? Icons.play_circle_fill_rounded
                        : _detectedLinkType == 'instagram'
                            ? Icons.camera_alt_rounded
                            : Icons.link_rounded,
                    size: 18,
                    color: _detectedLinkType == 'youtube'
                        ? Colors.red
                        : _detectedLinkType == 'instagram'
                            ? Colors.purpleAccent
                            : (isDark ? ZynkColors.darkMuted : const Color(0xFF64748B)),
                  ),
                  filled: true,
                  fillColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _linkTitleController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Link label / title (optional)',
                  hintStyle: TextStyle(color: isDark ? ZynkColors.darkMuted : const Color(0xFF94A3B8), fontSize: 12),
                  prefixIcon: Icon(Icons.title_rounded, size: 18, color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B)),
                  filled: true,
                  fillColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),

              // Save Changes Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZynkColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).brightness == Brightness.light
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.light
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSlot({
    required String title,
    required String subtitle,
    required IconData icon,
    required Uint8List? newBytes,
    required String? existingUrl,
    required bool isRemoved,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasImage = newBytes != null || (!isRemoved && existingUrl != null && existingUrl.isNotEmpty);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 105,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(ZynkRadius.md),
          border: Border.all(
            color: hasImage ? ZynkColors.primary : Theme.of(context).colorScheme.outlineVariant,
            width: hasImage ? 1.5 : 1.0,
          ),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                    child: newBytes != null
                        ? Image.memory(newBytes, fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: existingUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded, color: ZynkColors.darkMuted),
                            ),
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(ZynkRadius.md - 1),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onClear,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: ZynkColors.primary, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
