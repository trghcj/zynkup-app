import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/user/services/user_service.dart';
import 'package:zynkup/features/events/screens/edit_event_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    final isRegistered =
        userId != null && event.registeredUsers.contains(userId);

    final isAdmin =
        userId != null && userId == event.organizerId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          event.title,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditEventScreen(event: event),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🖼 IMAGE SLIDER
            _buildImageCarousel(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// DESCRIPTION
                  Text(
                    event.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 20),

                  _infoRow(
                    Icons.calendar_today,
                    'Date & Time',
                    DateFormat('MMM dd, yyyy • hh:mm a')
                        .format(event.date),
                    Colors.deepPurple,
                  ),

                  const SizedBox(height: 12),

                  _infoRow(
                    Icons.location_on,
                    'Venue',
                    event.venue,
                    Colors.red,
                  ),

                  const SizedBox(height: 12),

                  _infoRow(
                    Icons.category,
                    'Category',
                    event.category.name.toUpperCase(),
                    Colors.blue,
                  ),

                  const SizedBox(height: 28),

                  /// 🔳 QR CODE
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: event.id,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  /// 🟣 REGISTER BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: userId == null || isRegistered
                          ? null
                          : () => _register(
                                context,
                                userId,
                                event.id,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRegistered
                            ? Colors.grey
                            : Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isRegistered
                            ? 'Already Registered'
                            : userId == null
                                ? 'Login Required'
                                : 'Register Now',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🖼 IMAGE CAROUSEL
  Widget _buildImageCarousel() {
    if (event.imageUrls.isEmpty) {
      return _imagePlaceholder();
    }

    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: event.imageUrls.length,
        itemBuilder: (context, index) {
          return Image.network(
            event.imageUrls[index],
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) =>
                _imagePlaceholder(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
          );
        },
      ),
    );
  }

  /// ℹ INFO ROW
  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  /// 🟢 REGISTER USER
  Future<void> _register(
    BuildContext context,
    String userId,
    String eventId,
  ) async {
    try {
      await UserService()
          .registerForEvent(userId, eventId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Successfully registered 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 🔴 DELETE EVENT
  Future<void> _confirmDelete(
      BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
            'Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('events')
        .doc(event.id)
        .delete();

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event deleted'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 🖼 PLACEHOLDER
  Widget _imagePlaceholder() {
    return Container(
      height: 220,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.image,
          size: 50,
          color: Colors.grey,
        ),
      ),
    );
  }
}
