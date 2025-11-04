import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/features/user/models/user_model.dart';
import 'package:zynkup/features/user/services/user_service.dart';
import 'package:zynkup/features/events/screens/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  UserRole _selectedRole = UserRole.participant;
  final userService = UserService();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final email = FirebaseAuth.instance.currentUser!.email!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              const Text('Select Role', style: TextStyle(fontSize: 16)),
              ...UserRole.values.map((role) => RadioListTile<UserRole>(
                    title: Text(role.name.toUpperCase()),
                    value: role,
                    groupValue: _selectedRole,
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  )),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = AppUser(
      uid: uid,
      email: email,
      name: nameController.text,
      role: _selectedRole,
    );
    await userService.createUserProfile(user);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }
}