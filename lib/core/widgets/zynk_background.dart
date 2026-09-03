import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class ZynkBackground extends StatelessWidget {
  final Widget child;
  const ZynkBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base dark background
        Container(
          color: ZynkColors.darkBg,
        ),
        
        // Very subtle warm orange glow near top/selected areas
        Positioned(
          top: -150,
          left: -150,
          child: _Orb(
            color: const Color(0xFFFF8A1F).withValues(alpha: 0.04), // Extremely subtle
            size: 500,
          ),
        ),
        
        // Very subtle purple glow near opposite/background areas
        Positioned(
          bottom: -200,
          right: -100,
          child: _Orb(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.03), // Extremely subtle
            size: 600,
          ),
        ),

        // Content
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;

  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
