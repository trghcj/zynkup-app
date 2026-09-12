import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/theme_provider.dart';

/// Wraps the entire app and plays a double 3-D page-turn animation when the
/// theme changes.
///
/// Sequence (1 000 ms total, easeInOut):
///   Flip 1 — t 0.00 → 0.25 : screen folds away (old theme, 0° → -90°)
///   Flip 1 — t 0.25 → 0.50 : new theme unfolds  (new theme, 90° → 0°)
///   Flip 2 — t 0.50 → 0.75 : new theme folds away again (0° → -90°)
///   Flip 2 — t 0.75 → 1.00 : new theme settles back     (90° → 0°)
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
      duration: const Duration(milliseconds: 1000),
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

        // ── Determine rotation angle and whether to mirror content ──────
        //
        // Each quarter of [0,1] is one half-turn phase:
        //   [0.00, 0.25]  Flip-1 fold:   0° → -90°   (old theme folding away)
        //   [0.25, 0.50]  Flip-1 unfold: 90° →  0°   (new theme coming in — mirror)
        //   [0.50, 0.75]  Flip-2 fold:   0° → -90°   (new theme folds briefly)
        //   [0.75, 1.00]  Flip-2 unfold: 90° →  0°   (new theme settles — mirror)
        //
        // When showing the "back face" (unfold phases) we counter-rotate content
        // by π so it reads left-to-right instead of being mirrored.

        double angle;
        bool needsMirror;

        if (t < 0.25) {
          // Flip-1 fold-away (old theme disappears)
          final p = t / 0.25;
          angle = -math.pi / 2 * p;
          needsMirror = false;
        } else if (t < 0.50) {
          // Flip-1 unfold (new theme appears)
          final p = (t - 0.25) / 0.25;
          angle = math.pi / 2 * (1.0 - p);
          needsMirror = true;
        } else if (t < 0.75) {
          // Flip-2 fold-away (new theme briefly folds again)
          final p = (t - 0.50) / 0.25;
          angle = -math.pi / 2 * p;
          needsMirror = false;
        } else {
          // Flip-2 unfold (new theme settles into place)
          final p = (t - 0.75) / 0.25;
          angle = math.pi / 2 * (1.0 - p);
          needsMirror = true;
        }

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0008) // perspective depth
          ..rotateY(angle);

        Widget child = widget.child;
        if (needsMirror) {
          // Counter-rotate so content is readable on the back face
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
