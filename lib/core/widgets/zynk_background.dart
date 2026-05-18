import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class ZynkBackground extends StatefulWidget {
  final Widget child;
  const ZynkBackground({super.key, required this.child});

  @override
  State<ZynkBackground> createState() => _ZynkBackgroundState();
}

class _ZynkBackgroundState extends State<ZynkBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Deep Space Base
        Container(color: ZynkColors.darkBg),

        // 2. Animated Floating Orbs
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final t = _anim.value * 2 * math.pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Gold Orb (Top Right)
                Positioned(
                  top: -100 + math.sin(t) * 40,
                  right: -50 + math.cos(t) * 30,
                  child: _Orb(
                    color: ZynkColors.gold.withValues(alpha: 0.15),
                    size: 300,
                  ),
                ),
                // Deep Olive Orb (Bottom Left)
                Positioned(
                  bottom: -150 + math.cos(t * 1.5) * 50,
                  left: -100 + math.sin(t * 0.8) * 40,
                  child: _Orb(
                    color: ZynkColors.deepOlive.withValues(alpha: 0.25),
                    size: 400,
                  ),
                ),
                // Orange Accent Orb (Center Right)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.4 + math.sin(t * 1.2) * 60,
                  right: -150 + math.cos(t * 1.1) * 20,
                  child: _Orb(
                    color: ZynkColors.orange.withValues(alpha: 0.08),
                    size: 250,
                  ),
                ),
              ],
            );
          },
        ),

        // 3. Subtle Noise Texture Overlay (Optional, using a semi-transparent dark layer for now to blend)
        Container(
          color: ZynkColors.darkBg.withValues(alpha: 0.6),
        ),

        // 4. Content
        widget.child,
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
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
