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
        // 1. Deep Space Gradient base instead of muddy brown
        Container(
          decoration: const BoxDecoration(
            gradient: ZynkGradients.warmDark,
          ),
        ),

        // 2. Cinematic Drifting category-accented glows (Tech-Blue, Seminar-Purple, Sports-Green)
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final t = _anim.value * 2 * math.pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Tech Cyber-Cyan Glow Orb (Pulsing Top Left)
                Positioned(
                  top: -120 + math.sin(t) * 35,
                  left: -80 + math.cos(t * 0.8) * 45,
                  child: _Orb(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    size: 320,
                  ),
                ),
                // Seminar Magenta Glow Orb (Pulsing Bottom Right)
                Positioned(
                  bottom: -150 + math.cos(t * 1.2) * 55,
                  right: -100 + math.sin(t * 0.9) * 35,
                  child: _Orb(
                    color: const Color(0xFFD500F9).withValues(alpha: 0.18),
                    size: 380,
                  ),
                ),
                // Energy Yellow/Gold Glow Orb (Drifting Center Left)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.35 + math.sin(t * 0.7) * 40,
                  left: -120 + math.cos(t * 1.4) * 30,
                  child: _Orb(
                    color: const Color(0xFFFFEA00).withValues(alpha: 0.12),
                    size: 260,
                  ),
                ),
              ],
            );
          },
        ),

        // 3. Subtle Technical Canvas Grid Pattern Overlay
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(),
          ),
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
        filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.012)
      ..strokeWidth = 1.0;

    const spacing = 45.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
