import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/theme/theme_provider.dart';

/// Wraps the entire app and plays an authentic 2.5D page-turn animation when
/// the theme changes.
///
/// Rather than 3D card flips (which mirror/invert text), this renders a
/// physical page curl originating from the top-right corner and turning smoothly
/// across the screen to the bottom-left — revealing the new theme underneath
/// with realistic paper curl highlights and drop shadows, keeping all
/// typography 100% upright and legible throughout the transition.
class ThemePageTurn extends StatefulWidget {
  final Widget child;
  const ThemePageTurn({super.key, required this.child});

  @override
  State<ThemePageTurn> createState() => _ThemePageTurnState();
}

class _ThemePageTurnState extends State<ThemePageTurn>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late AnimationController _ctrl;
  late Animation<double> _anim;

  ui.Image? _oldPageImage;
  bool _oldIsDark = true;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    themeProvider.onBeforeThemeChange = _captureCurrentPage;
    themeProvider.addListener(_onThemeChange);
  }

  /// Captures a raster snapshot of the current screen before theme changes
  Future<void> _captureCurrentPage() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null && boundary.hasSize) {
        final dpr = (WidgetsBinding
                    .instance.platformDispatcher.views.firstOrNull?.devicePixelRatio ??
                1.5)
            .clamp(1.0, 2.0);
        final image = await boundary.toImage(pixelRatio: dpr);
        _oldPageImage?.dispose();
        _oldPageImage = image;
        _oldIsDark = themeProvider.isDark;
      }
    } catch (_) {
      // Fallback: painter will use solid theme background if capture fails
    }
  }

  void _onThemeChange() {
    if (!_animating) {
      setState(() => _animating = true);
      _ctrl.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _animating = false;
            _oldPageImage?.dispose();
            _oldPageImage = null;
            _ctrl.reset();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChange);
    if (themeProvider.onBeforeThemeChange == _captureCurrentPage) {
      themeProvider.onBeforeThemeChange = null;
    }
    _oldPageImage?.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childWithBoundary = RepaintBoundary(
      key: _boundaryKey,
      child: widget.child,
    );

    if (!_animating) {
      return childWithBoundary;
    }

    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return CustomPaint(
            foregroundPainter: _PageCurlPainter(
              progress: _anim.value,
              oldImage: _oldPageImage,
              isOldDark: _oldIsDark,
            ),
            child: childWithBoundary,
          );
        },
      ),
    );
  }
}

/// Custom painter that renders the top-right corner page curl / peel effect.
class _PageCurlPainter extends CustomPainter {
  final double progress;
  final ui.Image? oldImage;
  final bool isOldDark;

  _PageCurlPainter({
    required this.progress,
    required this.oldImage,
    required this.isOldDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    if (W <= 0 || H <= 0 || progress >= 1.0) return;

    final D = math.sqrt(W * W + H * H);
    final cosTheta = W / D;
    final sinTheta = H / D;

    // Normal pointing towards the peeled corner (top-right)
    final nx = cosTheta;
    final ny = -sinTheta;
    final normal = Offset(nx, ny);

    // Distance coordinate s(x, y) along the peel diagonal: 0 at (W, 0) to D at (0, H)
    double s(double x, double y) => (W - x) * cosTheta + y * sinTheta;

    // S travels smoothly across the screen diagonal with a small margin so it starts
    // before the top-right corner and completes fully past the bottom-left corner.
    final S = progress * (D + 40.0) - 20.0;

    // Intersections of the fold line with the 4 screen boundaries
    final xTop = W - S * D / W;
    final yRight = S * D / H;
    final yLeft = (S * D - W * W) / H;
    final xBottom = W - (S * D - H * H) / W;

    // Build the unpeeled polygon in counter-clockwise order starting from Bottom-Left (0, H)
    final poly = <Offset>[];
    Offset? foldP1;
    Offset? foldP2;

    // 1. Bottom-Left corner is always in the unpeeled region
    poly.add(Offset(0, H));

    // 2. Along bottom edge (BL -> BR)
    if (xBottom > 0 && xBottom < W) {
      final p = Offset(xBottom, H);
      poly.add(p);
      foldP1 ??= p;
    } else if (s(W, H) >= S) {
      poly.add(Offset(W, H));
    }

    // 3. Along right edge (BR -> TR)
    if (yRight > 0 && yRight < H) {
      final p = Offset(W, yRight);
      poly.add(p);
      if (foldP1 == null) {
        foldP1 = p;
      } else {
        foldP2 ??= p;
      }
    } else if (s(W, 0) >= S) {
      poly.add(Offset(W, 0));
    }

    // 4. Along top edge (TR -> TL)
    if (xTop > 0 && xTop < W) {
      final p = Offset(xTop, 0);
      poly.add(p);
      if (foldP1 == null) {
        foldP1 = p;
      } else {
        foldP2 ??= p;
      }
    }
    if (s(0, 0) >= S) {
      poly.add(Offset(0, 0));
    }

    // 5. Along left edge (TL -> BL)
    if (yLeft > 0 && yLeft < H) {
      final p = Offset(0, yLeft);
      poly.add(p);
      foldP2 ??= p;
    }

    if (poly.length < 3) return;

    // Organic bow along the fold line to simulate flexible paper held by hand
    final bowAmount = 14.0 * math.sin(math.pi * progress.clamp(0.0, 1.0));
    final hasFoldLine = foldP1 != null && foldP2 != null;

    final unpeeledPath = Path();
    unpeeledPath.moveTo(poly[0].dx, poly[0].dy);

    for (int i = 1; i < poly.length; i++) {
      final prev = poly[i - 1];
      final curr = poly[i];
      // If traversing the fold line between P1 and P2, bow slightly towards normal
      if (hasFoldLine &&
          ((prev == foldP1 && curr == foldP2) ||
              (prev == foldP2 && curr == foldP1))) {
        final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
        final ctrl = mid + normal * bowAmount;
        unpeeledPath.quadraticBezierTo(ctrl.dx, ctrl.dy, curr.dx, curr.dy);
      } else {
        unpeeledPath.lineTo(curr.dx, curr.dy);
      }
    }

    // Check closing segment back to poly[0]
    final last = poly.last;
    final first = poly.first;
    if (hasFoldLine &&
        ((last == foldP1 && first == foldP2) ||
            (last == foldP2 && first == foldP1))) {
      final mid = Offset((last.dx + first.dx) / 2, (last.dy + first.dy) / 2);
      final ctrl = mid + normal * bowAmount;
      unpeeledPath.quadraticBezierTo(ctrl.dx, ctrl.dy, first.dx, first.dy);
    } else {
      unpeeledPath.close();
    }

    // ── 1. Draw the Unpeeled Region (Old Theme Screen) ───────────────
    canvas.save();
    canvas.clipPath(unpeeledPath);

    if (oldImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        oldImage!.width.toDouble(),
        oldImage!.height.toDouble(),
      );
      final dst = Rect.fromLTWH(0, 0, W, H);
      final paint = Paint()..filterQuality = FilterQuality.medium;
      canvas.drawImageRect(oldImage!, src, dst, paint);
    } else {
      final fallbackPaint = Paint()
        ..color = isOldDark ? ZynkColors.darkBg : ZynkColors.lightBg;
      canvas.drawRect(Rect.fromLTWH(0, 0, W, H), fallbackPaint);
    }
    canvas.restore();

    // ── 2. Draw Page Curl Flap & Realistic Shadows ───────────────────
    if (hasFoldLine) {
      final p1 = foldP1;
      final p2 = foldP2;
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final ctrl = mid + normal * bowAmount;

      const curlWidth = 36.0;
      const shadowWidth = 28.0;
      const innerShadowWidth = 14.0;

      // Drop shadow cast onto the revealed new page underneath
      final shadowP1 = p1 + normal * shadowWidth;
      final shadowP2 = p2 + normal * shadowWidth;
      final shadowCtrl = ctrl + normal * shadowWidth;

      final shadowPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy)
        ..lineTo(shadowP2.dx, shadowP2.dy)
        ..quadraticBezierTo(shadowCtrl.dx, shadowCtrl.dy, shadowP1.dx, shadowP1.dy)
        ..close();

      final shadowGrad = ui.Gradient.linear(
        mid,
        mid + normal * shadowWidth,
        [
          Colors.black.withValues(alpha: 0.38),
          Colors.black.withValues(alpha: 0.0),
        ],
      );
      final shadowPaint = Paint()..shader = shadowGrad;
      canvas.drawPath(shadowPath, shadowPaint);

      // Curled paper cylinder / flap along the fold line
      final curlP1 = p1 + normal * curlWidth;
      final curlP2 = p2 + normal * curlWidth;
      final curlCtrl = ctrl + normal * curlWidth;

      final curlPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy)
        ..lineTo(curlP2.dx, curlP2.dy)
        ..quadraticBezierTo(curlCtrl.dx, curlCtrl.dy, curlP1.dx, curlP1.dy)
        ..close();

      final List<Color> curlColors = isOldDark
          ? [
              Colors.black.withValues(alpha: 0.55),
              const Color(0xFF1E2433),
              const Color(0xFF323D54),
              const Color(0xFF181C26),
              Colors.black.withValues(alpha: 0.35),
            ]
          : [
              Colors.black.withValues(alpha: 0.28),
              const Color(0xFFF0F2F6),
              const Color(0xFFFFFFFF),
              const Color(0xFFE3E7EE),
              Colors.black.withValues(alpha: 0.22),
            ];

      final curlGrad = ui.Gradient.linear(
        mid,
        mid + normal * curlWidth,
        curlColors,
        const [0.0, 0.22, 0.55, 0.85, 1.0],
      );
      final curlPaint = Paint()..shader = curlGrad;
      canvas.drawPath(curlPath, curlPaint);

      // Inner crease shadow on the old page
      final innerP1 = p1 - normal * innerShadowWidth;
      final innerP2 = p2 - normal * innerShadowWidth;
      final innerCtrl = ctrl - normal * innerShadowWidth;

      final innerPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy)
        ..lineTo(innerP2.dx, innerP2.dy)
        ..quadraticBezierTo(innerCtrl.dx, innerCtrl.dy, innerP1.dx, innerP1.dy)
        ..close();

      final innerGrad = ui.Gradient.linear(
        mid,
        mid - normal * innerShadowWidth,
        [
          Colors.black.withValues(alpha: 0.25),
          Colors.black.withValues(alpha: 0.0),
        ],
      );
      final innerPaint = Paint()..shader = innerGrad;
      canvas.drawPath(innerPath, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PageCurlPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.oldImage != oldImage ||
        oldDelegate.isOldDark != isOldDark;
  }
}
