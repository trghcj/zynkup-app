import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/home/screens/home_screen.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/core/widgets/full_screen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';class EventGalleryScreen extends StatefulWidget {
  const EventGalleryScreen({
    super.key,
    required this.event,
    this.canUpload = false,
  });

  final Event event;
  final bool canUpload;

  @override
  State<EventGalleryScreen> createState() => _EventGalleryScreenState();
}

class _EventGalleryScreenState extends State<EventGalleryScreen> {
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {});
    try {
      final files = await ApiService.fetchGalleryFiles(
        int.parse(widget.event.id),
      );
      if (!mounted) return;
      setState(() {
        _files = files.where(_hasRenderableMedia).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // FIX: 400 on gallery fetch = no gallery yet, treat as empty not error
        _files = [];
      });
    }
  }

  bool _hasRenderableMedia(Map<String, dynamic> file) {
    final url = file['url']?.toString();
    final data = file['data']?.toString();
    final mime = file['mime']?.toString();
    return (url != null && url.isNotEmpty) ||
        (data != null && data.isNotEmpty) ||
        mime == 'application/pdf' ||
        (mime != null && mime.startsWith('video/'));
  }

  Future<void> _upload() async {
    // FIX: on web, pickMultiImage works but we need to handle it gracefully
    List<XFile> images;
    try {
      images = await _picker.pickMultipleMedia(imageQuality: 85);
    } catch (e) {
      _snack(
        'Could not open image picker. Try a different browser.',
        error: true,
      );
      return;
    }

    if (images.isEmpty) return;
    setState(() => _uploading = true);

    try {
      final bytes = <Uint8List>[];
      final names = <String>[];

      for (final image in images) {
        // FIX: readAsBytes() works correctly on Flutter Web
        final b = await image.readAsBytes();
        bytes.add(b);
        // FIX: sanitize filename for web (may have fake path prefix)
        names.add(image.name.split('/').last.split('\\').last);
      }

      final uploaded = await ApiService.uploadEventGallery(
        eventId: int.parse(widget.event.id),
        files: bytes,
        filenames: names,
      );

      if (!mounted) return;
      if (uploaded.isNotEmpty) {
        bool hasVideo = names.any((n) => n.toLowerCase().endsWith('.mp4') || n.toLowerCase().endsWith('.mov') || n.toLowerCase().endsWith('.avi') || n.toLowerCase().endsWith('.mkv'));
        if (hasVideo && names.length == 1) {
          _snack('Video uploaded successfully!');
        } else if (hasVideo && names.length > 1) {
          _snack('Media uploaded successfully!');
        } else {
          _snack('Pictures uploaded successfully!');
        }
        await _load();
      } else {
        _snack('No files were uploaded.', error: true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      _snack('Upload failed. Check your connection.', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteFile(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZynkColors.darkSurface,
        title: const Text('Delete File', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to remove this file from the gallery?', style: TextStyle(color: ZynkColors.darkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: ZynkColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    final success = await ApiService.deleteEventGalleryFile(
      int.parse(widget.event.id),
      index,
    );
    if (!mounted) return;
    if (success) {
      _snack('File deleted successfully.');
      await _load();
    } else {
      setState(() => _loading = false);
      _snack('Failed to delete file.', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? ZynkColors.error : ZynkColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () async {
              await ApiService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                // ignore: use_build_context_synchronously
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false,
              );
            },
          ),
          if (widget.canUpload)
            IconButton(
              onPressed: _uploading ? null : _upload,
              tooltip: 'Add photos',
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ZynkColors.gold),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZynkColors.gold))
          : _files.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: ZynkColors.gold.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: ZynkColors.gold.withValues(alpha: 0.5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.canUpload
                        ? 'Upload the first event memory.'
                        : 'Photos will appear after the event.',
                    style: const TextStyle(
                      color: ZynkColors.darkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.canUpload) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 200,
                      child: ZynkButton(
                        label: 'Add photos',
                        icon: Icons.add_photo_alternate_rounded,
                        onTap: _uploading ? null : _upload,
                        isLoading: _uploading,
                        height: 46,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _files.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, index) => _GalleryTile(
                file: _files[index],
                canUpload: widget.canUpload,
                onDelete: () => _deleteFile(index),
              ),
            ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.file, this.canUpload = false, this.onDelete});
  final Map<String, dynamic> file;
  final bool canUpload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget content;
    final mime = file['mime']?.toString() ?? '';

    if (mime.startsWith('video/')) {
      final url = file['url']?.toString();
      content = GestureDetector(
        onTap: () {
          if (url != null && url.isNotEmpty) {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: ZynkGradients.cardSurface,
            borderRadius: BorderRadius.circular(ZynkRadius.md),
            border: Border.all(color: ZynkColors.darkBorder.withValues(alpha: 0.4)),
          ),
          child: const Icon(
            Icons.play_circle_fill_rounded,
            color: ZynkColors.gold,
            size: 32,
          ),
        ),
      );
    } else if (mime == 'application/pdf') {
      content = Container(
        decoration: BoxDecoration(
          gradient: ZynkGradients.cardSurface,
          borderRadius: BorderRadius.circular(ZynkRadius.md),
          border: Border.all(color: ZynkColors.darkBorder.withValues(alpha: 0.4)),
        ),
        child: const Icon(
          Icons.picture_as_pdf_rounded,
          color: ZynkColors.error,
        ),
      );
    } else {
      final url = file['url']?.toString();
      final data = file['data']?.toString();
      
      if (url != null && url.isNotEmpty) {
        content = GestureDetector(
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
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: ZynkGradients.cardSurface,
                  borderRadius: BorderRadius.circular(ZynkRadius.md),
                ),
                child: Icon(
                  Icons.broken_image_rounded,
                  color: ZynkColors.darkMuted.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        );
      } else if (data != null && data.isNotEmpty) {
        try {
          final bytes = base64Decode(data);
          content = ClipRRect(
            borderRadius: BorderRadius.circular(ZynkRadius.md),
            child: Image.memory(bytes, fit: BoxFit.cover),
          );
        } catch (_) {
          content = _buildErrorContainer();
        }
      } else {
        content = _buildErrorContainer();
      }
    }

    if (!canUpload) return content;

    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContainer() {
    return Container(
      decoration: BoxDecoration(
        gradient: ZynkGradients.cardSurface,
        borderRadius: BorderRadius.circular(ZynkRadius.md),
      ),
      child: Icon(
        Icons.broken_image_rounded,
        color: ZynkColors.darkMuted.withValues(alpha: 0.5),
      ),
    );
  }
}
