// lib/features/user/screens/user_event_details_screen.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class UserEventDetailsScreen extends StatefulWidget {
  final Event event;
  const UserEventDetailsScreen({super.key, required this.event});

  @override
  State<UserEventDetailsScreen> createState() => _UserEventDetailsScreenState();
}

class _UserEventDetailsScreenState extends State<UserEventDetailsScreen> {
  late Event _event;
  int _currentImageIndex = 0;
  bool _registering = false;
  bool _registered = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Open URL — works on web too ────────────────────────────────────────────
  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (kIsWeb) {
        // On Flutter Web use launchUrl with webOnlyWindowName
        await launchUrl(uri, webOnlyWindowName: '_blank');
      } else {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not open link. Try copying the URL.'),
          backgroundColor: ZynkColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  // ── Register for event ─────────────────────────────────────────────────────
  Future<void> _register() async {
    setState(() => _registering = true);
    try {
      final success =
          await ApiService.registerEvent(int.parse(_event.id));
      if (mounted) {
        if (success) {
          // Update local attendee count
          setState(() {
            _registered = true;
            _event = _event.copyWith(
              registeredUsers: [
                ..._event.registeredUsers,
                'me', // placeholder — real count comes from server
              ],
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.celebration_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Registered successfully! 🎉'),
            ]),
            backgroundColor: ZynkColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Already registered or registration failed'),
            backgroundColor: ZynkColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Registration failed. Try again.'),
          backgroundColor: ZynkColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
    if (mounted) setState(() => _registering = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark     = Theme.of(context).brightness == Brightness.dark;
    final catColor = ZynkColors.forCategory(_event.category.name);
    final hasImages = _event.imageUrls.isNotEmpty;
    final hasQr    = _event.registrationUrl != null &&
        _event.registrationUrl!.isNotEmpty;
    final isPast   = _event.date.isBefore(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero image / gradient ─────────────────────────
          SliverAppBar(
            expandedHeight: hasImages ? 300 : 180,
            pinned: true,
            foregroundColor: Colors.white,
            backgroundColor: ZynkColors.primaryDark,
            // ✅ No actions — removed edit button for users
            flexibleSpace: FlexibleSpaceBar(
              background: hasImages
                  ? _ImageCarousel(
                      imageUrls: _event.imageUrls,
                      pageController: _pageController,
                      currentIndex: _currentImageIndex,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                    )
                  : Container(
                      decoration: BoxDecoration(
                          gradient: ZynkGradients.forCategory(
                              _event.category.name)),
                      child: const Icon(Icons.event_rounded,
                          color: Colors.white24, size: 80),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status badges ─────────────────────────
                  Row(children: [
                    CategoryBadge(_event.category.name),
                    const SizedBox(width: 8),
                    if (_event.isApproved)
                      _Badge('APPROVED', ZynkColors.success,
                          Icons.verified_rounded)
                    else
                      _Badge('PENDING', ZynkColors.warning,
                          Icons.pending_rounded),
                    if (isPast) ...[
                      const SizedBox(width: 8),
                      _Badge('ENDED', ZynkColors.lightMuted,
                          Icons.event_busy_rounded),
                    ],
                  ]),

                  const SizedBox(height: 12),

                  Text(_event.title,
                      style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: dark
                            ? ZynkColors.darkText
                            : ZynkColors.lightText,
                      )),

                  const SizedBox(height: 14),

                  Text(_event.description,
                      style: TextStyle(
                        fontSize: 15, height: 1.7,
                        color: dark
                            ? ZynkColors.darkMuted
                            : ZynkColors.lightMuted,
                      )),

                  const SizedBox(height: 24),
                  const ZynkDivider(label: 'Event Info'),
                  const SizedBox(height: 16),

                  _InfoTile(icon: Icons.calendar_today_rounded,
                      label: 'Date & Time',
                      value: DateFormat('EEE, MMM dd, yyyy • hh:mm a')
                          .format(_event.date),
                      color: catColor, dark: dark),
                  const SizedBox(height: 10),
                  _InfoTile(icon: Icons.location_on_rounded,
                      label: 'Venue', value: _event.venue,
                      color: catColor, dark: dark),
                  const SizedBox(height: 10),
                  _InfoTile(
                      icon: Icons.category_rounded, label: 'Category',
                      value: _event.category.name[0].toUpperCase() +
                          _event.category.name.substring(1),
                      color: catColor, dark: dark),
                  const SizedBox(height: 10),

                  // ── Attendees — updates after register ────
                  _InfoTile(icon: Icons.people_rounded,
                      label: 'Registered',
                      value: '${_event.registeredUsers.length} attendees',
                      color: catColor, dark: dark),

                  // ── Register button (if approved & not past) ──
                  if (_event.isApproved && !isPast && !hasQr) ...[
                    const SizedBox(height: 24),
                    ZynkButton(
                      label: _registered
                          ? 'Already Registered ✓'
                          : 'Register for Event',
                      icon: _registered
                          ? Icons.check_circle_rounded
                          : Icons.how_to_reg_rounded,
                      isLoading: _registering,
                      bgColor: _registered
                          ? ZynkColors.success
                          : ZynkColors.primary,
                      onTap: _registered ? null : _register,
                    ),
                  ],

                  // ── QR Registration ───────────────────────
                  if (hasQr) ...[
                    const SizedBox(height: 24),
                    const ZynkDivider(label: 'Register'),
                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: dark
                            ? ZynkColors.darkSurface
                            : ZynkColors.lightSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: dark
                                ? ZynkColors.darkBorder
                                : ZynkColors.lightBorder)),
                      child: Column(children: [
                        Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: ZynkColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.qr_code_rounded,
                                color: ZynkColors.primary, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _event.registrationUrlType ==
                                        RegistrationUrlType.googleForm
                                    ? 'Google Form Registration'
                                    : 'Online Registration',
                                style: TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: dark
                                        ? ZynkColors.darkText
                                        : ZynkColors.lightText)),
                              Text('Scan QR or tap button below',
                                  style: TextStyle(fontSize: 12,
                                      color: dark
                                          ? ZynkColors.darkMuted
                                          : ZynkColors.lightMuted)),
                            ],
                          )),
                        ]),

                        const SizedBox(height: 20),

                        // QR — always white bg
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16)),
                          child: QrImageView(
                              data: _event.registrationUrl!,
                              size: 180,
                              backgroundColor: Colors.white),
                        ),

                        const SizedBox(height: 8),
                        Text('Scan with your camera to open the form',
                            style: TextStyle(fontSize: 12,
                                color: dark
                                    ? ZynkColors.darkMuted
                                    : ZynkColors.lightMuted)),

                        const SizedBox(height: 20),

                        // ✅ Fixed: opens in new tab on web
                        ZynkButton(
                          label: _event.registrationUrlType ==
                                  RegistrationUrlType.googleForm
                              ? 'Open Google Form'
                              : 'Open Registration Link',
                          icon: Icons.open_in_new_rounded,
                          onTap: () =>
                              _openUrl(_event.registrationUrl!),
                        ),

                        const SizedBox(height: 10),

                        // URL preview
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: dark
                                  ? ZynkColors.darkSurface2
                                  : ZynkColors.lightSurf2,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            Icon(Icons.link_rounded, size: 14,
                                color: dark
                                    ? ZynkColors.darkMuted
                                    : ZynkColors.lightMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_event.registrationUrl!,
                                  style: TextStyle(fontSize: 11,
                                      color: dark
                                          ? ZynkColors.darkMuted
                                          : ZynkColors.lightMuted),
                                  overflow: TextOverflow.ellipsis)),
                          ]),
                        ),

                        // Also register internally
                        if (_event.isApproved && !isPast) ...[
                          const SizedBox(height: 12),
                          ZynkButton(
                            label: _registered
                                ? 'Registered ✓'
                                : 'Mark as Registered',
                            icon: _registered
                                ? Icons.check_circle_rounded
                                : Icons.how_to_reg_rounded,
                            isLoading: _registering,
                            bgColor: _registered
                                ? ZynkColors.success
                                : ZynkColors.catTech,
                            outlined: !_registered,
                            onTap: _registered ? null : _register,
                          ),
                        ],
                      ]),
                    ),
                  ],

                  // Pending
                  if (!_event.isApproved) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ZynkColors.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: ZynkColors.warning.withOpacity(0.25))),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Icon(Icons.pending_actions_rounded,
                            color: ZynkColors.warning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          'This event is awaiting admin approval.',
                          style: TextStyle(fontSize: 12, height: 1.5,
                              color: dark
                                  ? ZynkColors.darkText.withOpacity(0.7)
                                  : ZynkColors.lightText.withOpacity(0.7)))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image Carousel — handles both URL and base64 ──────────────────────────────

class _ImageCarousel extends StatelessWidget {
  final List<String> imageUrls;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const _ImageCarousel({
    required this.imageUrls,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      PageView.builder(
        controller: pageController,
        onPageChanged: onPageChanged,
        itemCount: imageUrls.length,
        itemBuilder: (_, i) => _SmartImage(url: imageUrls[i]),
      ),
      if (imageUrls.length > 1)
        Positioned(
          bottom: 12, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(imageUrls.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: currentIndex == i ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: currentIndex == i
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3)),
              )),
          ),
        ),
    ]);
  }
}

/// Displays base64 data URLs OR regular http URLs
class _SmartImage extends StatelessWidget {
  final String url;
  const _SmartImage({required this.url});

  @override
  Widget build(BuildContext context) {
    // ✅ Handle base64 data URLs
    if (url.startsWith('data:')) {
      try {
        final b64 = url.split(',').last;
        final bytes = base64Decode(b64);
        return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity,
            errorBuilder: (_, __, ___) => _placeholder());
      } catch (_) {
        return _placeholder();
      }
    }

    // Regular network URL
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(color: ZynkColors.darkSurface2,
              child: Center(child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
                color: ZynkColors.primary, strokeWidth: 2))),
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    color: ZynkColors.darkSurface2,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
      const SizedBox(height: 8),
      Text('Image unavailable',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
    ]),
  );
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label; final Color color; final IconData icon;
  const _Badge(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 9, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
          color: color, letterSpacing: 0.5)),
    ]));
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label, value;
  final Color color; final bool dark;
  const _InfoTile({required this.icon, required this.label,
      required this.value, required this.color, required this.dark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder)),
    child: Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: dark ? ZynkColors.darkText : ZynkColors.lightText)),
      ])),
    ]));
}