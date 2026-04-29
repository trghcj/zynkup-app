// lib/features/auth/screens/login_choice_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/admin/screens/admin_login_screen.dart';
import 'package:zynkup/features/user/screens/user_login_screen.dart';

class LoginChoiceScreen extends StatefulWidget {
  const LoginChoiceScreen({super.key});

  @override
  State<LoginChoiceScreen> createState() => _LoginChoiceScreenState();
}

class _LoginChoiceScreenState extends State<LoginChoiceScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _cardsController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _card1Fade;
  late Animation<double> _card2Fade;
  late Animation<Offset> _card1Slide;
  late Animation<Offset> _card2Slide;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _cardsController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
            begin: const Offset(0, -0.1), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _heroController, curve: Curves.easeOut));

    _card1Fade = CurvedAnimation(
        parent: _cardsController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _card2Fade = CurvedAnimation(
        parent: _cardsController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut));
    _card1Slide = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _cardsController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _card2Slide = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _cardsController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut)));

    Future.delayed(const Duration(milliseconds: 100),
        () => _heroController.forward());
    Future.delayed(const Duration(milliseconds: 400),
        () => _cardsController.forward());
  }

  @override
  void dispose() {
    _heroController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ──────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF18120E), Color(0xFF2D1A0E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // ── Decorative circles ──────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZynkColors.primary.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ZynkColors.accent.withOpacity(0.06),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────
          SafeArea(
            child: isWide
                ? Row(children: [
                    Expanded(child: _HeroPanel(
                      fadeAnim: _heroFade,
                      slideAnim: _heroSlide,
                    )),
                    Expanded(child: _CardsPanel(
                      card1Fade: _card1Fade,
                      card2Fade: _card2Fade,
                      card1Slide: _card1Slide,
                      card2Slide: _card2Slide,
                    )),
                  ])
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _heroFade,
                        child: SlideTransition(
                          position: _heroSlide,
                          child: _HeroContent(),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _CardsPanel(
                        card1Fade: _card1Fade,
                        card2Fade: _card2Fade,
                        card1Slide: _card1Slide,
                        card2Slide: _card2Slide,
                      ),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;

  const _HeroPanel(
      {required this.fadeAnim, required this.slideAnim});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: FadeTransition(
        opacity: fadeAnim,
        child: SlideTransition(
          position: slideAnim,
          child: _HeroContent(),
        ),
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: ZynkGradients.brand,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: ZynkColors.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded,
              color: Colors.white, size: 36),
        ),

        const SizedBox(height: 28),

        const Text(
          'ZYNKUP',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1,
            height: 1,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          width: 56,
          height: 3,
          decoration: BoxDecoration(
            gradient: ZynkGradients.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Manage campus events\neffortlessly.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.7),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),

        // Feature pills
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Pill('📅 Event Management'),
          _Pill('📊 Analytics'),
          _Pill('🎫 QR Registration'),
          _Pill('📱 Real-time Updates'),
        ]),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CardsPanel extends StatelessWidget {
  final Animation<double> card1Fade;
  final Animation<double> card2Fade;
  final Animation<Offset> card1Slide;
  final Animation<Offset> card2Slide;

  const _CardsPanel({
    required this.card1Fade,
    required this.card2Fade,
    required this.card1Slide,
    required this.card2Slide,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Who are you?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),

          // Admin card
          FadeTransition(
            opacity: card1Fade,
            child: SlideTransition(
              position: card1Slide,
              child: _RoleCard(
                title: 'Admin / Organizer',
                subtitle: 'Manage events & users',
                icon: Icons.admin_panel_settings_rounded,
                gradient: ZynkGradients.brand,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminLoginScreen()),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Student card
          FadeTransition(
            opacity: card2Fade,
            child: SlideTransition(
              position: card2Slide,
              child: _RoleCard(
                title: 'Student / Guest',
                subtitle: 'Browse & register for events',
                icon: Icons.school_rounded,
                color: ZynkColors.darkSurface,
                borderColor: ZynkColors.darkBorder,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const UserLoginScreen()),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'MAIT Event Platform',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient? gradient;
  final Color? color;
  final Color? borderColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.gradient,
    this.color,
    this.borderColor,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : _hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              color: widget.color,
              borderRadius: BorderRadius.circular(20),
              border: widget.borderColor != null
                  ? Border.all(color: widget.borderColor!)
                  : null,
              boxShadow: _hovered && widget.gradient != null
                  ? [
                      BoxShadow(
                        color: ZynkColors.primary.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      )
                    ]
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                      widget.gradient != null ? 0.2 : 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon,
                    color: widget.gradient != null
                        ? Colors.white
                        : ZynkColors.primary,
                    size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: widget.gradient != null
                            ? Colors.white
                            : ZynkColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.gradient != null
                            ? Colors.white.withOpacity(0.75)
                            : ZynkColors.darkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: widget.gradient != null
                    ? Colors.white.withOpacity(0.7)
                    : ZynkColors.darkMuted,
                size: 20,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}