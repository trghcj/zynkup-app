import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/guest_home_screen.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class EventGalleryScreen extends StatefulWidget {
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
    setState(() { });
    try {
      final files = await ApiService.fetchGalleryFiles(
        int.parse(widget.event.id),
      );
      if (!mounted) return;
      setState(() {
        _files = files;
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

  Future<void> _upload() async {
    // FIX: on web, pickMultiImage works but we need to handle it gracefully
    List<XFile> images;
    try {
      images = await _picker.pickMultiImage(imageQuality: 85);
    } catch (e) {
      _snack('Could not open image picker. Try a different browser.', error: true);
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

      final ok = await ApiService.uploadEventGallery(
        eventId: int.parse(widget.event.id),
        files: bytes,
        filenames: names,
      );

      if (!mounted) return;
      if (ok) {
        _snack('Photos uploaded!');
        await _load();
      } else {
        _snack('Upload failed. Check your connection.', error: true);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Upload error: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
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
                MaterialPageRoute(builder: (_) => const GuestHomeScreen()),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        color: ZynkColors.darkMuted,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.canUpload
                            ? 'Upload the first event memory.'
                            : 'Photos will appear after the event.',
                        style:
                            const TextStyle(color: ZynkColors.darkMuted),
                      ),
                      if (widget.canUpload) ...[
                        const SizedBox(height: 16),
                        // FIX: also provide a centre upload button so users
                        // don't miss the icon in the app bar
                        ElevatedButton.icon(
                          onPressed: _uploading ? null : _upload,
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          label: const Text('Add photos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZynkColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _files.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (_, index) =>
                      _GalleryTile(file: _files[index]),
                ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.file});
  final Map<String, dynamic> file;

  @override
  Widget build(BuildContext context) {
    final mime = file['mime']?.toString() ?? '';

    if (mime == 'application/pdf') {
      return Container(
        color: ZynkColors.darkSurface,
        child: const Icon(Icons.picture_as_pdf_rounded, color: ZynkColors.error),
      );
    }

    // FIX: support both base64 'data' field AND direct 'url' field from backend
    final url = file['url']?.toString();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: ZynkColors.darkSurface,
            child: const Icon(Icons.broken_image_rounded,
                color: ZynkColors.darkMuted),
          ),
        ),
      );
    }

    // Fallback: base64 encoded data
    final data = file['data']?.toString();
    if (data != null && data.isNotEmpty) {
      try {
        final bytes = base64Decode(data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      } catch (_) {}
    }

    return Container(
      color: ZynkColors.darkSurface,
      child: const Icon(Icons.broken_image_rounded, color: ZynkColors.darkMuted),
    );
  }
}