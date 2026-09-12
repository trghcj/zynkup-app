import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/theme_provider.dart';

/// Wraps the entire app and plays a 3-D page-turn animation when the theme
/// changes — like turning a physical book page at medium speed (~600 ms).
class ThemePageTurn extends StatefulWidget {
  final Widget child;
  const ThemePageTurn({super.key, required this.child});

  @override
  State<ThemePageTurn> createState() => _ThemePageTurnState();
}

class _ThemePageTurnState extends State<ThemePageTurn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    themeProvider.addListener(_onThemeChange);
  }

  void _onThemeChange() {
    if (!_animating) {
      setState(() => _animating = true);
      _ctrl.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _animating = false;
            _ctrl.reset();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChange);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_animating) return widget.child;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value; // 0.0 → 1.0

        // Phase 1 (0→0.5): rotate 0° → -90° (page folds away)
        // Phase 2 (0.5→1): rotate +90° → 0° (page unfolds on new side)
        final double angle =
            t < 0.5 ? -math.pi * t : math.pi * (1.0 - t);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0008) // perspective
          ..rotateY(angle);

        // Past the fold mid-point the new theme is visible; we flip the face
        // so the content reads correctly (not mirrored).
        Widget child = widget.child;
        if (t >= 0.5) {
          child = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: child,
          );
        }

        return Transform(
          alignment: Alignment.center,
          transform: matrix,
          child: child,
        );
      },
    );
  }
}
