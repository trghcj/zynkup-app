// lib/features/user/screens/profile_setup_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/core/utils/string_extensions.dart';
import 'package:zynkup/features/user/models/user_model.dart';
import 'package:zynkup/features/user/services/user_service.dart';
import 'package:zynkup/features/events/screens/home_screen.dart'; // SINGLE HOME SCREEN

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  UserRole _selectedRole = UserRole.participant;
  final _userService = UserService();

  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final String _email = FirebaseAuth.instance.currentUser!.email ?? '';

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = AppUser(
        uid: _uid,
        email: _email,
        name: _nameController.text.trim(),
        role: _selectedRole,
        createdAt: DateTime.now(),
        isProfileComplete: true,
      );

      await _userService.createUserProfile(user);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar;
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Welcome to Zynkup! Profile saved', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
        ),
      );

      // GO TO OUR SINGLE HOME SCREEN (Admin/User handled automatically)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseException catch (e) {
      _showError(e.message ?? 'Failed to save profile');
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.purpleAccent],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Avatar Circle
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 80,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Complete Your Profile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Help us know you better',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 40),

                // Form Card
                Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name Field
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline, color: Colors.deepPurple),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: Colors.deepPurple.shade50,
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Name is required';
                              if (v.trim().length < 2) return 'Name too short';
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // Role Selection Title
                          Text(
                            'I am a...',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Role Options
                          ...UserRole.values.map((role) {
                            final isSelected = _selectedRole == role;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.deepPurple.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: RadioListTile<UserRole>(
                                  title: Text(
                                    role.name.capitalize(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.deepPurple : Colors.black87,
                                      fontSize: 17,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _getRoleDescription(role),
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                  value: role,
                                  groupValue: _selectedRole,
                                  onChanged: _isLoading ? null : (val) => setState(() => _selectedRole = val!),
                                  activeColor: Colors.deepPurple,
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            );
                          }).toList(),

                          const SizedBox(height: 40),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: Colors.deepPurple.withOpacity(0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: _isLoading
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                        ),
                                        SizedBox(width: 16),
                                        Text('Saving Profile...', style: TextStyle(fontSize: 16)),
                                      ],
                                    )
                                  : const Text(
                                      'Continue to Zynkup',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.participant:
        return 'Join events • Register • Explore campus life';
      case UserRole.organizer:
        return 'Create events • Manage registrations • Promote activities';
      case UserRole.admin:
        return 'Full control • Manage all events & users';
    }
  }
}