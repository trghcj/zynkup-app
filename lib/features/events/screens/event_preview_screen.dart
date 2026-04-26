import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import '../models/event_model.dart';

class EventPreviewScreen extends StatelessWidget {
  final Event event;
  final List<File>? pickedImages;
  final List<Uint8List>? webImages;

  const EventPreviewScreen({
    super.key,
    required this.event,
    this.pickedImages,
    this.webImages,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final catColor = ZynkColors.forCategory(event.category.name);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Image Hero ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildImagePreview(),
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PREVIEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Badge + Title ────────────────────────
                  CategoryBadge(event.category.name),
                  const SizedBox(height: 10),

                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Description ──────────────────────────
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Info Tiles ───────────────────────────
                  _infoTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date & Time',
                    value: DateFormat('EEE, MMM dd • hh:mm a').format(event.date),
                    color: catColor,
                    dark: dark,
                  ),
                  const SizedBox(height: 10),
                  _infoTile(
                    icon: Icons.location_on_rounded,
                    label: 'Venue',
                    value: event.venue,
                    color: catColor,
                    dark: dark,
                  ),
                  const SizedBox(height: 10),
                  _infoTile(
                    icon: Icons.category_rounded,
                    label: 'Event Type',
                    value: event.category.name.toUpperCase(),
                    color: catColor,
                    dark: dark,
                  ),

                  const SizedBox(height: 28),

                  // ── Preview Note ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ZynkColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: ZynkColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: ZynkColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This is a preview. The event will be submitted for admin approval.',
                            style: TextStyle(
                              fontSize: 12,
                              color: dark
                                  ? ZynkColors.darkText.withOpacity(0.7)
                                  : ZynkColors.lightText.withOpacity(0.7),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (kIsWeb && webImages != null && webImages!.isNotEmpty) {
      return PageView.builder(
        itemCount: webImages!.length,
        itemBuilder: (_, i) =>
            Image.memory(webImages![i], fit: BoxFit.cover),
      );
    }
    if (!kIsWeb && pickedImages != null && pickedImages!.isNotEmpty) {
      return PageView.builder(
        itemCount: pickedImages!.length,
        itemBuilder: (_, i) =>
            Image.file(pickedImages![i], fit: BoxFit.cover),
      );
    }
    return Container(
      decoration: const BoxDecoration(gradient: ZynkGradients.brand),
      child: const Icon(Icons.event_rounded, color: Colors.white30, size: 80),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dark ? ZynkColors.darkText : ZynkColors.lightText,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}