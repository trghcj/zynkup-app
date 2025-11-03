import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _dept = TextEditingController();
  final _year = TextEditingController();
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _saving = false;

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    await _fire.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': _name.text.trim(),
      'department': _dept.text.trim(),
      'year': _year.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _name.dispose();
    _dept.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: _dept, decoration: const InputDecoration(labelText: 'Department')),
            const SizedBox(height: 12),
            TextField(controller: _year, decoration: const InputDecoration(labelText: 'Year / Batch')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              child: _saving ? const CircularProgressIndicator() : const Text('Save Profile'),
            )
          ],
        ),
      ),
    );
  }
}
