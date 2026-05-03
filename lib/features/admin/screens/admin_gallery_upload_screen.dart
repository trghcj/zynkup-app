// lib/features/admin/screens/admin_gallery_upload_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class AdminGalleryUploadScreen extends StatefulWidget {
  final Event event;
  const AdminGalleryUploadScreen({super.key, required this.event});

  @override
  State<AdminGalleryUploadScreen> createState() =>
      _AdminGalleryUploadScreenState();
}

class _AdminGalleryUploadScreenState
    extends State<AdminGalleryUploadScreen> {
  List<Map<String, dynamic>> _existing = [];
  final List<Map<String, dynamic>> _newFiles  = [];
  bool _loading    = true;
  bool _uploading  = false;
  final ImagePicker _picker = ImagePicker();

  static const int _maxFiles = 50;
  static const int _maxMb    = 15;

  @override
  void initState() {
    super.initState();
    _fetchExisting();
  }

  Future<void> _fetchExisting() async {
    try {
      final res = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/events/${widget.event.id}/gallery'),
        headers: ApiService.authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _existing = List<Map<String, dynamic>>.from(data['files'] ?? []);
          _loading  = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  int get _totalCount => _existing.length + _newFiles.length;
  int get _remaining  => _maxFiles - _totalCount;

  // ── Pick images ─────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    if (_remaining <= 0) {
      _snack('Maximum $_maxFiles files reached', ZynkColors.warning);
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    int added = 0;
    for (final img in picked) {
      if (_totalCount + added >= _maxFiles) break;
      final bytes = await img.readAsBytes();
      if (bytes.length > _maxMb * 1024 * 1024) {
        _snack('${img.name} exceeds ${_maxMb}MB limit', ZynkColors.error);
        continue;
      }
      final ext  = img.name.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      setState(() => _newFiles.add({
        'name': img.name, 'mime': mime,
        'data': base64Encode(bytes), 'bytes': bytes,
      }));
      added++;
    }
    if (added > 0) _snack('$added image(s) added', ZynkColors.success);
  }

  // ── Delete existing file ─────────────────────────────────────────────────
  Future<void> _deleteExisting(int index) async {
    final confirm = await _confirmDialog(
        'Remove File',
        'Remove "${_existing[index]['name']}" from gallery?');
    if (confirm != true) return;

    try {
      final res = await http.delete(
        Uri.parse(
            '${ApiService.baseUrl}/events/${widget.event.id}/gallery/$index'),
        headers: ApiService.authHeaders,
      );
      if (res.statusCode == 200) {
        setState(() => _existing.removeAt(index));
        _snack('File removed', ZynkColors.success);
      }
    } catch (_) {
      _snack('Failed to remove file', ZynkColors.error);
    }
  }

  // ── Upload new files ─────────────────────────────────────────────────────
  Future<void> _upload() async {
    if (_newFiles.isEmpty) {
      _snack('No new files to upload', ZynkColors.warning);
      return;
    }
    setState(() => _uploading = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${ApiService.baseUrl}/events/${widget.event.id}/gallery'),
      );
      // FIX: must use authOnlyHeaders — authHeaders includes Content-Type: application/json
      // which overwrites the multipart boundary and corrupts the upload.
      request.headers.addAll(ApiService.authOnlyHeaders);

      for (final f in _newFiles) {
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          f['bytes'] as Uint8List,
          filename: f['name'] as String,
        ));
      }

      final streamed = await request.send();
      final res      = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _snack(
            '${_newFiles.length} file(s) uploaded! Total: ${data['total']}',
            ZynkColors.success);
        setState(() => _newFiles.clear());
        await _fetchExisting();
      } else {
        final err = jsonDecode(res.body);
        _snack(err['detail'] ?? 'Upload failed', ZynkColors.error);
      }
    } catch (e) {
      _snack('Upload error: $e', ZynkColors.error);
    }

    if (mounted) setState(() => _uploading = false);
  }

  Future<bool?> _confirmDialog(String title, String msg) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ZynkColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Event Gallery'),
          Text(widget.event.title,
              style: TextStyle(fontSize: 12,
                  color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
              overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          if (_newFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded,
                        color: Colors.white),
                label: Text('Upload (${_newFiles.length})',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: ZynkColors.primary))
          : Column(
              children: [
                // ── Stats bar ──────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurf2,
                  child: Row(children: [
                    _StatPill('Uploaded', _existing.length,
                        ZynkColors.success),
                    const SizedBox(width: 10),
                    _StatPill('Queued', _newFiles.length,
                        ZynkColors.warning),
                    const SizedBox(width: 10),
                    _StatPill('Remaining', _remaining, ZynkColors.catTech),
                    const Spacer(),
                    Text('Max $_maxFiles files',
                        style: TextStyle(fontSize: 11,
                            color: dark
                                ? ZynkColors.darkMuted
                                : ZynkColors.lightMuted)),
                  ]),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                      // ── Add files button ──────────────
                      GestureDetector(
                        onTap: _remaining > 0 ? _pickImages : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 90,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _remaining > 0
                                ? ZynkColors.primary.withValues(alpha: 0.06)
                                : (dark
                                    ? ZynkColors.darkSurface2
                                    : ZynkColors.lightSurf2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _remaining > 0
                                  ? ZynkColors.primary.withValues(alpha: 0.4)
                                  : (dark
                                      ? ZynkColors.darkBorder
                                      : ZynkColors.lightBorder),
                            ),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Icon(
                              _remaining > 0
                                  ? Icons.add_photo_alternate_rounded
                                  : Icons.block_rounded,
                              color: _remaining > 0
                                  ? ZynkColors.primary
                                  : ZynkColors.lightMuted,
                              size: 28),
                            const SizedBox(height: 6),
                            Text(
                              _remaining > 0
                                  ? 'Add Photos (PNG, JPG)'
                                  : 'Gallery Full ($_maxFiles/$_maxFiles)',
                              style: TextStyle(
                                color: _remaining > 0
                                    ? ZynkColors.primary
                                    : ZynkColors.lightMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            ),
                          ]),
                        ),
                      ),

                      // ── New files queue ───────────────
                      if (_newFiles.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _sectionLabel('📋 Queued for Upload',
                            ZynkColors.warning, dark),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: _newFiles.length,
                          itemBuilder: (_, i) => Stack(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _newFiles[i]['bytes'] as Uint8List,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) =>
                                    _imgPlaceholder(ZynkColors.warning),
                              ),
                            ),
                            // Queued badge
                            Positioned(top: 4, left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: ZynkColors.warning,
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Text('NEW',
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                            // Remove
                            Positioned(top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _newFiles.removeAt(i)),
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded,
                                      size: 13, color: Colors.white)),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        ZynkButton(
                          label: _uploading
                              ? 'Uploading...'
                              : 'Upload ${_newFiles.length} File(s)',
                          icon: Icons.cloud_upload_rounded,
                          isLoading: _uploading,
                          onTap: _upload,
                        ),
                      ],

                      // ── Existing gallery ──────────────
                      if (_existing.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _sectionLabel(
                            '✅ Uploaded (${_existing.length})',
                            ZynkColors.success, dark),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: _existing.length,
                          itemBuilder: (_, i) {
                            final f    = _existing[i];
                            final isPdf = f['mime'] == 'application/pdf';
                            Uint8List? bytes;
                            if (!isPdf) {
                              try {
                                bytes = base64Decode(f['data'] as String);
                              } catch (_) {}
                            }

                            return Stack(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: isPdf
                                    ? _imgPlaceholder(ZynkColors.error,
                                        icon: Icons.picture_as_pdf_rounded)
                                    : (bytes != null
                                        ? Image.memory(bytes,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity)
                                        : _imgPlaceholder(ZynkColors.primary)),
                              ),
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(10)),
                                  ),
                                  child: Text(
                                    f['name'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 8),
                                    overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              Positioned(top: 4, right: 4,
                                child: GestureDetector(
                                  onTap: () => _deleteExisting(i),
                                  child: Container(
                                    width: 22, height: 22,
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.delete_rounded,
                                        size: 12, color: Colors.white)),
                                ),
                              ),
                            ]);
                          },
                        ),
                      ],

                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(String label, Color color, bool dark) => Row(children: [
    Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
        color: dark ? ZynkColors.darkText : ZynkColors.lightText)),
  ]);

  Widget _imgPlaceholder(Color color,
      {IconData icon = Icons.image_rounded}) =>
      Container(
        color: color.withValues(alpha: 0.1),
        child: Center(child: Icon(icon, color: color, size: 28)));
}

class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20)),
    child: RichText(text: TextSpan(children: [
      TextSpan(text: '$count ',
          style: TextStyle(color: color, fontWeight: FontWeight.w800,
              fontSize: 13)),
      TextSpan(text: label,
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
    ])));
}