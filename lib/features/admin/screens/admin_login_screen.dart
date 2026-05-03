// lib/features/admin/screens/admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/admin/screens/admin_home_screen.dart';
import 'package:zynkup/features/auth/screens/login_choice_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  bool _hidePass = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
    _checkAlreadyLoggedIn();
  }

  Future<void> _checkAlreadyLoggedIn() async {
    if (ApiService.hasToken) {
      final user = await ApiService.getCurrentUser();
      if (user != null && user["role"] == "admin" && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
          (_) => false,
        );
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final res =
          await ApiService.login(_emailC.text.trim(), _passC.text.trim());
      if (!mounted) return;
      if (res["role"] != "admin") {
        _snack("This account doesn't have admin access.");
        await ApiService.logout();
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack("Connection error. Is the server running?");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ZynkColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  // ── Wide layout (tablet/web) — split panel ─────────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left brand panel — gold/dark theme for admin
        Expanded(
          child: Container(
            decoration: const BoxDecoration(gradient: ZynkGradients.brand),
            child: _buildBrandPanel(),
          ),
        ),
        // Right form panel
        Expanded(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildFormContent(isWide: true),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow layout (phone) ──────────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return Stack(
      children: [
        // Brand bg top strip
        Container(
          height: 280,
          decoration: const BoxDecoration(gradient: ZynkGradients.brand),
        ),

        // Decorative grid pattern
        Positioned(
          top: 40,
          right: 20,
          child: Opacity(
            opacity: 0.12,
            child: Icon(Icons.grid_4x4_rounded,
                size: 180, color: Colors.white),
          ),
        ),

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row — back + clear session
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        await ApiService.logout();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginChoiceScreen()),
                          (_) => false,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(children: [
                          Icon(Icons.logout_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Clear session',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin\nPortal.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Restricted access — authorised admins only',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // White card for form
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: _buildFormContent(isWide: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Left brand panel (wide only) ───────────────────────────────────────────
  Widget _buildBrandPanel() {
    return Stack(
      children: [
        // Decorative patterns
        Positioned(
          bottom: -40,
          left: -40,
          child: Opacity(
            opacity: 0.1,
            child: Icon(Icons.grid_4x4_rounded,
                size: 280, color: Colors.white),
          ),
        ),
        Positioned(
          top: 60,
          right: -20,
          child: Opacity(
            opacity: 0.07,
            child: Icon(Icons.hexagon_outlined, size: 200, color: Colors.white),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('ZYNKUP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          )),
                    ],
                  ),
                ),

                const Spacer(),

                // Admin badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: ZynkGradients.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text('ADMIN ACCESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Admin\nPortal.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Restricted access.\nAuthorised admins only.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 15),
                ),

                const SizedBox(height: 40),

                // Capability chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _capChip(Icons.event_rounded, 'Manage Events'),
                    _capChip(Icons.people_rounded, 'View Users'),
                    _capChip(Icons.bar_chart_rounded, 'Analytics'),
                    _capChip(Icons.photo_library_rounded, 'Gallery'),
                  ],
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _capChip(IconData icon, String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // ── Shared form content ────────────────────────────────────────────────────
  Widget _buildFormContent({required bool isWide}) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWide) ...[
                // Back + clear session row for wide layout
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: dark
                              ? ZynkColors.darkSurface2
                              : ZynkColors.lightSurf2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: dark
                                  ? ZynkColors.darkBorder
                                  : ZynkColors.lightBorder),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: dark
                                ? ZynkColors.darkText
                                : ZynkColors.lightText),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        await ApiService.logout();
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginChoiceScreen()),
                          (_) => false,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: dark
                              ? ZynkColors.darkSurface2
                              : ZynkColors.lightSurf2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: dark
                                  ? ZynkColors.darkBorder
                                  : ZynkColors.lightBorder),
                        ),
                        child: Row(children: [
                          Icon(Icons.logout_rounded,
                              size: 14,
                              color: dark
                                  ? ZynkColors.darkMuted
                                  : ZynkColors.lightMuted),
                          const SizedBox(width: 4),
                          Text('Clear session',
                              style: TextStyle(
                                  color: dark
                                      ? ZynkColors.darkMuted
                                      : ZynkColors.lightMuted,
                                  fontSize: 12)),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Welcome back.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your admin account',
                  style: TextStyle(
                      color: dark
                          ? ZynkColors.darkMuted
                          : ZynkColors.lightMuted,
                      fontSize: 14),
                ),
                const SizedBox(height: 32),
              ] else ...[
                // Admin badge for narrow layout
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: ZynkGradients.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text('ADMIN ACCESS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Email
              TextFormField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Admin email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Enter your email'
                    : null,
              ),

              const SizedBox(height: 14),

              // Password
              TextFormField(
                controller: _passC,
                obscureText: _hidePass,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_hidePass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    onPressed: () =>
                        setState(() => _hidePass = !_hidePass),
                  ),
                ),
                validator: (v) => v == null || v.length < 6
                    ? 'Min 6 characters'
                    : null,
              ),

              const SizedBox(height: 28),

              ZynkButton(
                label: 'Sign In as Admin',
                icon: Icons.admin_panel_settings_rounded,
                onTap: _login,
                isLoading: _loading,
              ),

              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    '< Back',
                    style: TextStyle(
                      color:
                          dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}