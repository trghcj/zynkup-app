import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';

class EventPreviewScreen extends StatelessWidget {
  final Event event;

  /// For mobile (Android / iOS)
  final List<File>? pickedImages;

  /// For web
  final List<Uint8List>? webImages;

  const EventPreviewScreen({
    super.key,
    required this.event,
    this.pickedImages,
    this.webImages,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Preview'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= IMAGES =================
            SizedBox(
              height: 240,
              width: double.infinity,
              child: _buildImagePreview(),
            ),

            // ================= CONTENT =================
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TITLE
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// DESCRIPTION
                  Text(
                    event.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  _infoRow(
                    icon: Icons.calendar_today,
                    label: 'Date & Time',
                    value: DateFormat('EEE, MMM dd • hh:mm a')
                        .format(event.date),
                  ),

                  const SizedBox(height: 12),

                  _infoRow(
                    icon: Icons.location_on,
                    label: 'Venue',
                    value: event.venue,
                  ),

                  const SizedBox(height: 12),

                  _infoRow(
                    icon: Icons.category,
                    label: 'Event Type',
                    value: event.category.name.toUpperCase(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= IMAGE PREVIEW =================

  Widget _buildImagePreview() {
    // ---------- WEB ----------
    if (kIsWeb && webImages != null && webImages!.isNotEmpty) {
      return PageView.builder(
        itemCount: webImages!.length,
        itemBuilder: (_, index) {
          return Image.memory(
            webImages![index],
            fit: BoxFit.cover,
          );
        },
      );
    }

    // ---------- MOBILE ----------
    if (!kIsWeb && pickedImages != null && pickedImages!.isNotEmpty) {
      return PageView.builder(
        itemCount: pickedImages!.length,
        itemBuilder: (_, index) {
          return Image.file(
            pickedImages![index],
            fit: BoxFit.cover,
          );
        },
      );
    }

    // ---------- FALLBACK ----------
    return _imagePlaceholder();
  }

  // ================= HELPERS =================

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.deepPurple),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 240,
      width: double.infinity,
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(
          Icons.image,
          size: 60,
          color: Colors.grey,
        ),
      ),
    );
  }
}
