import 'package:flutter/material.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_list_screen.dart';
import 'package:zynkup/features/auth/services/auth_service.dart';
// Import CreateEventScreen when ready

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EventCategory _selectedCategory = EventCategory.tech;  // Default

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zynkup Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              // AuthWrapper handles redirect to login
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filters
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: EventCategory.values.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category.toString().split('.').last.capitalize()),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // Event List
          Expanded(
            child: EventListScreen(category: _selectedCategory),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to CreateEventScreen (implement in Week 4)
          // For now: ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create Event Coming Soon')));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Extension for capitalize
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}