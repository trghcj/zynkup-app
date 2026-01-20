import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zynkup/features/events/screens/create_event_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      // Modern AppBar with gradient + shadow
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6A1B9A), Color(0xFF7B1FA2)],
            ),
          ),
        ),
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: 'Logout',
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
            ),
          ),
        ],
      ),

      // FAB with modern style
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateEventScreen(),
              ),
            );
          },
          backgroundColor: const Color(0xFF6A1B9A),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Create New Event',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),

      // Body with nice content
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, Admin!',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6A1B9A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage all events and create new ones with ease.',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildActionCard(
                      icon: Icons.event_available_rounded,
                      title: 'Create Event',
                      color: Colors.deepPurple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                        );
                      },
                    ),
                    _buildActionCard(
                      icon: Icons.list_alt_rounded,
                      title: 'View All Events',
                      color: Colors.blue,
                      onTap: () {
                        // You can add navigation to event list later
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Event list view coming soon!')),
                        );
                      },
                    ),
                    _buildActionCard(
                      icon: Icons.people_rounded,
                      title: 'Manage Users',
                      color: Colors.teal,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User management coming soon!')),
                        );
                      },
                    ),
                    _buildActionCard(
                      icon: Icons.analytics_rounded,
                      title: 'Analytics',
                      color: Colors.orange,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Analytics dashboard coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}