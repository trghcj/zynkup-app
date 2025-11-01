import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _branch = TextEditingController();
  final _year = TextEditingController();

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': user.displayName,
      'email': user.email,
      'branch': _branch.text,
      'year': int.tryParse(_year.text),
      'role': 'student',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile Setup")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _branch, decoration: const InputDecoration(labelText: "Branch")),
            TextField(controller: _year, decoration: const InputDecoration(labelText: "Year")),
            ElevatedButton(
              onPressed: () async {
                await saveProfile();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }
}
