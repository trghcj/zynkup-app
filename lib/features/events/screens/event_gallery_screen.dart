import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class EventGalleryScreen extends StatefulWidget {
  final Event event;
  const EventGalleryScreen({super.key, required this.event});

  @override
  State<EventGalleryScreen> createState() => _EventGalleryScreenState();
}

class _EventGalleryScreenState extends State<EventGalleryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fetchGallery();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // FIX: Use ApiService.getEventGallery() instead of manual http call
  // that accessed the private ApiService._token field.
  Future<void> _fetchGallery() async {
    try {
      final eventId = int.tryParse(widget.event.id);
      if (eventId == null) {
        setState(() => _loading = false);
        return;
      }

      // getEventGallery returns List<Map<String,dynamic>> from the backend's
      // /events/{id}/gallery endpoint (same JSON shape the UI expects).
      final res = await ApiService.fetchGalleryFiles(eventId);

      setState(() {
        _files = res;
        _loading = false;
      });
      _animCtrl.forward();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final catColor = ZynkColors.forCategory(widget.event.category.name);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Event Gallery'),
          Text(widget.event.title,
              style: TextStyle(
                  fontSize: 12,
                  color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
              overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          if (_files.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_files.length} files',
                  style: TextStyle(
                      color: catColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: ZynkColors.primary))
          : _files.isEmpty
              ? _emptyState(dark)
              : _buildGrid(dark, catColor),
    );
  }

  Widget _emptyState(bool dark) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: ZynkColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.photo_library_rounded,
                  color: ZynkColors.primary, size: 36)),
          const SizedBox(height: 16),
          Text('No gallery yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color:
                      dark ? ZynkColors.darkText : ZynkColors.lightText)),
          const SizedBox(height: 6),
          Text('Post-event photos will appear here',
              style: TextStyle(
                  color: dark
                      ? ZynkColors.darkMuted
                      : ZynkColors.lightMuted)),
        ]),
      );

  Widget _buildGrid(bool dark, Color catColor) {
    final images =
        _files.where((f) => f['mime'] != 'application/pdf').toList();
    final pdfs =
        _files.where((f) => f['mime'] == 'application/pdf').toList();

    return RefreshIndicator(
      color: ZynkColors.primary,
      onRefresh: _fetchGallery,
      child: CustomScrollView(
        slivers: [
          // ── Image grid ───────────────────────────────
          if (images.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child:
                    _sectionLabel('📸 Photos (${images.length})', dark),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _GalleryImageTile(
                    file: images[i],
                    index: i,
                    allImages: images,
                    animCtrl: _animCtrl,
                    dark: dark,
                  ),
                  childCount: images.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
              ),
            ),
          ],

          // ── PDFs ─────────────────────────────────────
          if (pdfs.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _sectionLabel(
                    '📄 Documents (${pdfs.length})', dark),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _PdfTile(file: pdfs[i], dark: dark),
                  childCount: pdfs.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, bool dark) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color:
                    dark ? ZynkColors.darkText : ZynkColors.lightText)),
      );
}

// ── Image tile with tap to fullscreen ────────────────────────────────────────

class _GalleryImageTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final int index;
  final List<Map<String, dynamic>> allImages;
  final AnimationController animCtrl;
  final bool dark;

  const _GalleryImageTile({
    required this.file,
    required this.index,
    required this.allImages,
    required this.animCtrl,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.05).clamp(0.0, 0.8);
    final anim = CurvedAnimation(
      parent: animCtrl,
      curve: Interval(delay, (delay + 0.3).clamp(0.0, 1.0),
          curve: Curves.easeOutBack),
    );

    Uint8List? bytes;
    try {
      bytes = base64Decode(file['data'] as String);
    } catch (_) {}

    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1.0).animate(anim),
      child: FadeTransition(
        opacity: anim,
        child: GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _FullscreenGallery(
                    images: allImages, initialIndex: index),
              )),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover)
                : Container(
                    color: ZynkColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.image_rounded,
                        color: ZynkColors.primary)),
          ),
        ),
      ),
    );
  }
}

// ── PDF tile ──────────────────────────────────────────────────────────────────

class _PdfTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final bool dark;
  const _PdfTile({required this.file, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color:
                dark ? ZynkColors.darkBorder : ZynkColors.lightBorder)),
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ZynkColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: ZynkColors.error, size: 24)),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(file['name'] ?? 'Document',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: dark
                        ? ZynkColors.darkText
                        : ZynkColors.lightText),
                overflow: TextOverflow.ellipsis),
            Text('PDF Document',
                style: TextStyle(
                    fontSize: 12,
                    color: dark
                        ? ZynkColors.darkMuted
                        : ZynkColors.lightMuted)),
          ],
        )),
        Icon(Icons.chevron_right_rounded,
            color:
                dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
      ]),
    );
  }
}

// ── Fullscreen gallery viewer ─────────────────────────────────────────────────

class _FullscreenGallery extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  const _FullscreenGallery(
      {required this.images, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.images.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ),
      body: PageView.builder(
        controller: _ctrl,
        onPageChanged: (i) => setState(() => _current = i),
        itemCount: widget.images.length,
        itemBuilder: (_, i) {
          Uint8List? bytes;
          try {
            bytes = base64Decode(widget.images[i]['data'] as String);
          } catch (_) {}

          return InteractiveViewer(
            child: Center(
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.contain)
                  : const Icon(Icons.broken_image_rounded,
                      color: Colors.white38, size: 60),
            ),
          );
        },
      ),
    );
  }
}