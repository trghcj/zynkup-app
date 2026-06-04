import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/login_prompt_sheet.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_gallery_screen.dart';
import 'package:zynkup/features/events/screens/qr_scanner_screen.dart';
import 'package:zynkup/core/widgets/full_screen_image_viewer.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    required this.event,
    this.isGuest = false,
  });

  final Event event;
  final bool isGuest;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late Event _event;
  bool _loading = true;
  bool _registering = false;
  bool _deleting = false;
  // FIX: persist QR across _load() calls — never overwrite with null
  String? _qrCode;
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _qrCode = widget.event.qrCode;
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getEventById(int.parse(_event.id));
    final user = widget.isGuest ? null : await ApiService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _event = Event.fromJson(data);
        final freshQr = data['qr_code']?.toString();
        if (freshQr != null && freshQr.isNotEmpty) {
          _qrCode = freshQr;
        }
      }
      _isCreator = user != null && user['id'].toString() == _event.organizerId;
      if (_isCreator) {
        _qrCode = null;
      }
      _loading = false;
    });
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(event: _event),
      ),
    );
  }

  Future<void> _register() async {
    if (widget.isGuest || !ApiService.hasToken) {
      showLoginPrompt(context, message: 'Sign in to register and receive your QR pass.');
      return;
    }
    setState(() => _registering = true);
    try {
      final result = await ApiService.registerEvent(int.parse(_event.id));
      if (!mounted) return;
      // FIX: set QR immediately from register response BEFORE _load() can clear it
      final newQr = result['qr_code']?.toString();
      if (newQr != null && newQr.isNotEmpty) {
        setState(() => _qrCode = newQr);
      }
      _snack('Registered. Your QR pass is ready.');
      // _load() will now only UPDATE _qrCode if backend returns it, not clear it
      await _load();
    } on ApiException catch (error) {
      _snack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _share() async {
    final baseUrl = kIsWeb ? Uri.base.origin : 'https://zynkup-app.vercel.app';
    final text = 'Join ${_event.title} on Zynkup: $baseUrl/events/${_event.id}';
    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      _snack('Event link copied.');
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ZynkColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZynkRadius.xl),
          side: const BorderSide(color: ZynkColors.darkBorder),
        ),
        title: const Text(
          'Delete event?',
          style: TextStyle(color: ZynkColors.darkText, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'This will permanently remove "${_event.title}" and all registrations.',
          style: const TextStyle(color: ZynkColors.darkMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: ZynkColors.darkMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ZynkColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZynkRadius.md),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    final deleted = await ApiService.deleteEvent(int.parse(_event.id));
    if (!mounted) return;
    setState(() => _deleting = false);
    if (deleted) {
      _snack('Event deleted.');
      Navigator.pop(context, true);
    } else {
      _snack('Could not delete this event.', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? ZynkColors.error : ZynkColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final joined = _event.attendeeCount > 0
        ? _event.attendeeCount
        : _event.registeredUsers.length;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Scaffold(
          backgroundColor: ZynkColors.darkBg,
          body: ZynkBackground(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: ZynkColors.gold))
                : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 280,
                  backgroundColor: ZynkColors.darkSurface,
                  actions: [
                    IconButton(
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                    if (_isCreator)
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        onPressed: _openScanner,
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _HeroImage(event: _event),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CategoryBadge(_event.category.name),
                        const SizedBox(height: 14),
                        Text(
                          _event.title,
                          style: const TextStyle(
                            color: ZynkColors.darkText,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: ZynkColors.gold,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: ZynkColors.gold.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$joined student${joined == 1 ? '' : 's'} joined',
                              style: const TextStyle(
                                color: ZynkColors.gold,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _Info(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date & Time',
                          value: DateFormat(
                            'EEE, MMM d - h:mm a',
                          ).format(_event.date),
                        ),
                        _Info(
                          icon: Icons.location_on_rounded,
                          label: 'Venue',
                          value: _event.venue,
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'About',
                          style: TextStyle(
                            color: ZynkColors.darkText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _event.description,
                          style: TextStyle(
                            color: ZynkColors.darkMuted.withValues(alpha: 0.9),
                            height: 1.6,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _ActionRow(
                          isCreator: _isCreator,
                          isGuest: widget.isGuest,
                          isRegistered: _event.isRegistered || _qrCode != null,
                          registering: _registering,
                          onRegister: _register,
                          onShare: _share,
                          onScan: _openScanner,
                        ),
                        // FIX: QR is now persistent — shown whenever _qrCode is non-null
                        if (!_isCreator && _qrCode != null) ...[
                          const SizedBox(height: 24),
                          _QrPass(qrCode: _qrCode!),
                        ],
                        const SizedBox(height: 18),
                        ZynkButton(
                          label: _isCreator ? 'Manage Gallery' : 'View Gallery',
                          icon: Icons.photo_library_rounded,
                          outlined: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventGalleryScreen(
                                event: _event,
                                canUpload: _isCreator,
                              ),
                            ),
                          ),
                        ),
                        if (_isCreator) ...[
                          const SizedBox(height: 12),
                          ZynkButton(
                            label: 'Delete Event',
                            icon: Icons.delete_rounded,
                            outlined: true,
                            bgColor: ZynkColors.error,
                            isLoading: _deleting,
                            onTap: _deleteEvent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final image = event.imageUrls.isNotEmpty ? event.imageUrls.first : null;
    if (image == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: ZynkGradients.forCategory(event.category.name),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                ZynkColors.darkSurface.withValues(alpha: 0.5),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: 'event_image_${event.id}',
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImageViewer(imageUrl: image),
                ),
              );
            },
            child: Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: ZynkGradients.forCategory(event.category.name),
                ),
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                ZynkColors.darkSurface.withValues(alpha: 0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ZynkGradients.cardSurface,
        borderRadius: BorderRadius.circular(ZynkRadius.lg),
        border: Border.all(color: ZynkColors.darkBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ZynkColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: ZynkColors.gold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ZynkColors.darkMuted.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: ZynkColors.darkText,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isCreator,
    required this.isGuest,
    required this.isRegistered,
    required this.registering,
    required this.onRegister,
    required this.onShare,
    required this.onScan,
  });

  final bool isCreator;
  final bool isGuest;
  final bool isRegistered;
  final bool registering;
  final VoidCallback onRegister;
  final VoidCallback onShare;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    if (isCreator) {
      return Row(
        children: [
          Expanded(
            child: ZynkButton(
              label: 'Scan Attendance',
              icon: Icons.qr_code_scanner_rounded,
              onTap: onScan,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ZynkButton(
              label: 'Share',
              icon: Icons.ios_share_rounded,
              outlined: true,
              onTap: onShare,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ZynkButton(
            label: isGuest
                ? 'Login to participate'
                : isRegistered
                    ? 'QR Pass Ready'
                    : 'Register',
            icon: isRegistered
                ? Icons.qr_code_rounded
                : Icons.how_to_reg_rounded,
            isLoading: registering,
            onTap: onRegister,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ZynkButton(
            label: 'Share',
            icon: Icons.ios_share_rounded,
            outlined: true,
            onTap: onShare,
          ),
        ),
      ],
    );
  }
}

class _QrPass extends StatelessWidget {
  const _QrPass({required this.qrCode});
  final String qrCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ZynkGradients.cardSurface,
        borderRadius: BorderRadius.circular(ZynkRadius.xl),
        border: Border.all(color: ZynkColors.gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: ZynkColors.gold.withValues(alpha: 0.06),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.confirmation_number_rounded,
                  color: ZynkColors.gold.withValues(alpha: 0.7), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Your QR Pass',
                style: TextStyle(
                  color: ZynkColors.darkText,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ZynkRadius.md),
            ),
            child: QrImageView(data: qrCode, size: 180),
          ),
          const SizedBox(height: 12),
          Text(
            'Show this to the organizer for check-in',
            style: TextStyle(
              color: ZynkColors.darkMuted.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
