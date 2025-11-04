import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_list_screen.dart';
import 'package:zynkup/features/auth/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EventCategory _selectedCategory = EventCategory.tech;

  @override
  void initState() {
    super.initState();
    _generateIndexesOnce(); // ONE-TIME INDEX LINK GENERATOR
  }

  /// GENERATE INDEX LINKS (RUN ONCE, THEN DELETE)
  void _generateIndexesOnce() {
    final categories = ['tech', 'cultural', 'sports', 'workshop'];
    for (var cat in categories) {
      FirebaseFirestore.instance
          .collection('events')
          .where('category', isEqualTo: cat)
          .limit(1)
          .get()
          // ignore: body_might_complete_normally_catch_error
          .catchError((e) {
        if (e is FirebaseException && e.code == 'failed-precondition') {
          final link = e.message?.split('here: ').last ?? '';
          if (link.isNotEmpty) {
            print('\nCREATE INDEX FOR "$cat":');
            print(link);
            print('\n');
          }
        }
      });
    }
    print('Index links generated! Paste in browser → Create → DELETE this function.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zynkup Home'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out!')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // CATEGORY TABS
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: EventCategory.values.map((category) {
                final label = category.name.capitalize();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontWeight: _selectedCategory == category
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                    selectedColor: Colors.deepPurple,
                    backgroundColor: Colors.grey[200],
                    labelStyle: TextStyle(
                      color: _selectedCategory == category
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // EVENT LIST
          Expanded(
            child: EventListScreen(category: _selectedCategory),
          ),
        ],
      ),

      // CREATE EVENT BUTTON
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: () {
          // WEEK 4: UNCOMMENT BELOW
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );

          // TEMP: REMOVE AFTER CREATE SCREEN IS READY
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('Create Event Coming Soon!')),
          // );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Simple Create Event screen placeholder so navigation has a concrete class.
// Replace or remove this once the real create_event_screen.dart is implemented.
class CreateEventScreen extends StatelessWidget {
  const CreateEventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Create Event Screen - implement form here'),
      ),
    );
  }
}

// CAPITALIZE EXTENSION
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}