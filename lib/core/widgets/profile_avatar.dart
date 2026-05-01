
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;   // can be base64 data URL or https URL
  final double radius;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    required this.avatarUrl,
    this.radius = 21,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ZynkGradients.brand,
          boxShadow: [
            BoxShadow(
              color: ZynkColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(child: _buildImage()),
      ),
    );
  }

  Widget _buildImage() {
    final url = avatarUrl;

    if (url == null || url.isEmpty) {
      return const Icon(Icons.person_rounded, color: Colors.white, size: 22);
    }

    // Base64 data URL (e.g. "data:image/jpeg;base64,/9j/...")
    if (url.startsWith('data:')) {
      try {
        final commaIndex = url.indexOf(',');
        if (commaIndex != -1) {
          final base64Str = url.substring(commaIndex + 1);
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.person_rounded, color: Colors.white, size: 22),
          );
        }
      } catch (_) {}
      return const Icon(Icons.person_rounded, color: Colors.white, size: 22);
    }

    // Regular HTTPS URL
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.person_rounded, color: Colors.white, size: 22),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Icon(Icons.person_rounded, color: Colors.white, size: 22);
      },
    );
  }
}