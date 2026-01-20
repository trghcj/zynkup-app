import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class UserEventDetailsScreen extends StatelessWidget {
  final Event event;

  const UserEventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          event.title,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🖼 EVENT IMAGES (MULTIPLE)
            _imageSection(),

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
                    value: DateFormat('MMM dd, yyyy • hh:mm a')
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
                    label: 'Category',
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

  // ================= IMAGE SECTION =================

  Widget _imageSection() {
    if (event.imageUrls.isEmpty) {
      return _imagePlaceholder();
    }

    return SizedBox(
      height: 260,
      child: PageView.builder(
        itemCount: event.imageUrls.length,
        itemBuilder: (context, index) {
          return Image.network(
            event.imageUrls[index],
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _imagePlaceholder(),
          );
        },
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 260,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.image,
          size: 60,
          color: Colors.grey,
        ),
      ),
    );
  }

  // ================= INFO ROW =================

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
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
}
