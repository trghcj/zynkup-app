import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/user/services/user_service.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;
  const EventDetailsScreen({required this.event, super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isRegistered = userId != null && event.registeredUsers.contains(userId);
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          event.title,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            Text(
              event.description,
              style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 20),

            // Date & Time
            _buildInfoRow(
              icon: Icons.calendar_today,
              color: Colors.deepPurple,
              label: 'Date & Time',
              value: DateFormat('MMM dd, yyyy • hh:mm a').format(event.date),
            ),
            const SizedBox(height: 12),

            // Venue
            _buildInfoRow(
              icon: Icons.location_on,
              color: Colors.red,
              label: 'Venue',
              value: event.venue,
            ),
            const SizedBox(height: 12),

            // Category
            _buildInfoRow(
              icon: Icons.category,
              color: Colors.blue,
              label: 'Category',
              value: event.category.name.toUpperCase(),
            ),
            const SizedBox(height: 28),

            // QR Code
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: event.id,
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Register Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: userId == null
                    ? null
                    : isRegistered
                        ? null
                        : () => _register(context, userService, userId, event.id),
                icon: Icon(
                  isRegistered ? Icons.check_circle : Icons.app_registration,
                  size: 20,
                ),
                label: Text(
                  isRegistered
                      ? 'Already Registered'
                      : userId == null
                          ? 'Login Required'
                          : 'Register Now',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRegistered
                      ? Colors.grey
                      : userId == null
                          ? Colors.grey.shade400
                          : Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isRegistered ? 0 : 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Helper: Reusable info row
  Widget _buildInfoRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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

  // Register with error handling
  Future<void> _register(
    BuildContext context,
    UserService userService,
    String userId,
    String eventId,
  ) async {
    try {
      await userService.registerForEvent(userId, eventId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully registered!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseException catch (e) {
      String msg = 'Registration failed';
      if (e.code == 'permission-denied') {
        msg = 'You don\'t have permission';
      } else if (e.code == 'not-found') {
        msg = 'Event not found';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}