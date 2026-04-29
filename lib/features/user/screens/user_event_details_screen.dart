// lib/features/user/screens/user_event_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class UserEventDetailsScreen extends StatefulWidget {
  final Event event;
  const UserEventDetailsScreen({super.key, required this.event});

  @override
  State<UserEventDetailsScreen> createState() => _UserEventDetailsScreenState();
}

class _UserEventDetailsScreenState extends State<UserEventDetailsScreen> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not open the link'),
          backgroundColor: ZynkColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark     = Theme.of(context).brightness == Brightness.dark;
    final event    = widget.event;
    final catColor = ZynkColors.forCategory(event.category.name);
    final hasImages = event.imageUrls.isNotEmpty;
    final hasQr    = event.registrationUrl != null &&
        event.registrationUrl!.isNotEmpty;
    final isPast   = event.date.isBefore(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Image Hero ─────────────────────────────────
          SliverAppBar(
            expandedHeight: hasImages ? 300 : 180,
            pinned: true,
            foregroundColor: Colors.white,
            backgroundColor: ZynkColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              background: hasImages
                  ? _ImageCarousel(
                      imageUrls: event.imageUrls,
                      pageController: _pageController,
                      currentIndex: _currentImageIndex,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                    )
                  : Container(
                      decoration: BoxDecoration(
                          gradient: ZynkGradients.forCategory(
                              event.category.name)),
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
                  // ── Status badges ───────────────────────
                  Row(children: [
                    CategoryBadge(event.category.name),
                    const SizedBox(width: 8),
                    if (event.isApproved)
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

                  // ── Title ───────────────────────────────
                  Text(event.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: dark
                            ? ZynkColors.darkText
                            : ZynkColors.lightText,
                      )),

                  const SizedBox(height: 14),

                  // ── Description ─────────────────────────
                  Text(event.description,
                      style: TextStyle(
                        fontSize: 15, height: 1.7,
                        color: dark
                            ? ZynkColors.darkMuted
                            : ZynkColors.lightMuted,
                      )),

                  const SizedBox(height: 24),
                  const ZynkDivider(label: 'Event Info'),
                  const SizedBox(height: 16),

                  // ── Info tiles ──────────────────────────
                  _InfoTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date & Time',
                    value: DateFormat('EEE, MMM dd, yyyy • hh:mm a')
                        .format(event.date),
                    color: catColor, dark: dark,
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.location_on_rounded,
                    label: 'Venue',
                    value: event.venue,
                    color: catColor, dark: dark,
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.category_rounded,
                    label: 'Category',
                    value: event.category.name[0].toUpperCase() +
                        event.category.name.substring(1),
                    color: catColor, dark: dark,
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.people_rounded,
                    label: 'Registered',
                    value: '${event.registeredUsers.length} attendees',
                    color: catColor, dark: dark,
                  ),

                  // ── QR Registration ─────────────────────
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
                                : ZynkColors.lightBorder),
                      ),
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
                                event.registrationUrlType ==
                                        RegistrationUrlType.googleForm
                                    ? 'Google Form Registration'
                                    : 'Online Registration',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: dark ? ZynkColors.darkText : ZynkColors.lightText)),
                              Text('Scan QR or tap button below',
                                  style: TextStyle(fontSize: 12,
                                      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
                            ],
                          )),
                        ]),

                        const SizedBox(height: 20),

                        // QR always white bg for scanning
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16)),
                          child: QrImageView(
                              data: event.registrationUrl!,
                              size: 180,
                              backgroundColor: Colors.white),
                        ),

                        const SizedBox(height: 8),
                        Text('Point your camera at the QR code',
                            style: TextStyle(fontSize: 12,
                                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),

                        const SizedBox(height: 20),

                        ZynkButton(
                          label: event.registrationUrlType ==
                                  RegistrationUrlType.googleForm
                              ? 'Open Google Form'
                              : 'Open Registration Link',
                          icon: event.registrationUrlType ==
                                  RegistrationUrlType.googleForm
                              ? Icons.assignment_rounded
                              : Icons.open_in_new_rounded,
                          onTap: () => _launchUrl(event.registrationUrl!),
                        ),

                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            Icon(Icons.link_rounded, size: 14,
                                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(event.registrationUrl!,
                                  style: TextStyle(fontSize: 11,
                                      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
                                  overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                      ]),
                    ),
                  ],

                  // Pending state
                  if (!event.isApproved && !hasQr) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ZynkColors.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ZynkColors.warning.withOpacity(0.25))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.pending_actions_rounded, color: ZynkColors.warning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          'This event is awaiting admin approval.',
                          style: TextStyle(fontSize: 12, height: 1.5,
                              color: dark ? ZynkColors.darkText.withOpacity(0.7)
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

// ── Image Carousel with dots indicator ────────────────────────────────────────

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
    return Stack(
      children: [
        PageView.builder(
          controller: pageController,
          onPageChanged: onPageChanged,
          itemCount: imageUrls.length,
          itemBuilder: (_, i) => _NetworkImage(url: imageUrls[i]),
        ),

        // Dot indicators
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
                    borderRadius: BorderRadius.circular(3),
                  ),
                )),
            ),
          ),
      ],
    );
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;
  const _NetworkImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              color: ZynkColors.darkSurface2,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  color: ZynkColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
      errorBuilder: (_, __, ___) => Container(
        color: ZynkColors.darkSurface2,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.broken_image_rounded,
              color: Colors.white38, size: 48),
          const SizedBox(height: 8),
          Text('Image unavailable',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 12)),
        ]),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: color, letterSpacing: 0.5)),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool dark;

  const _InfoTile({
    required this.icon, required this.label,
    required this.value, required this.color, required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: dark ? ZynkColors.darkText : ZynkColors.lightText)),
          ],
        )),
      ]),
    );
  }
}