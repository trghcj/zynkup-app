import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
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
    final files = await ApiService.fetchGalleryFiles(
      int.parse(widget.event.id),
    );
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  Future<void> _upload() async {
    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (images.isEmpty) return;
    setState(() => _uploading = true);
    final bytes = <List<int>>[];
    final names = <String>[];
    for (final image in images) {
      bytes.add(await image.readAsBytes());
      names.add(image.name);
    }
    final ok = await ApiService.uploadEventGallery(
      eventId: int.parse(widget.event.id),
      files: bytes.map((item) => Uint8List.fromList(item)).toList(),
      filenames: names,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          if (widget.canUpload)
            IconButton(
              onPressed: _uploading ? null : _upload,
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
              child: Text(
                widget.canUpload
                    ? 'Upload the first event memory.'
                    : 'Photos will appear after the event.',
                style: const TextStyle(color: ZynkColors.darkMuted),
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
              itemBuilder: (_, index) => _GalleryTile(file: _files[index]),
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
        child: const Icon(
          Icons.picture_as_pdf_rounded,
          color: ZynkColors.error,
        ),
      );
    }
    try {
      final bytes = base64Decode(file['data'].toString());
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, fit: BoxFit.cover),
      );
    } catch (_) {
      return Container(
        color: ZynkColors.darkSurface,
        child: const Icon(
          Icons.broken_image_rounded,
          color: ZynkColors.darkMuted,
        ),
      );
    }
  }
}
