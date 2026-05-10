import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/auth/screens/login_screen.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_gallery_screen.dart';
import 'package:zynkup/features/events/screens/qr_scanner_screen.dart';

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
  // FIX: persist QR across _load() calls — never overwrite with null
  String? _qrCode;
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getEventById(int.parse(_event.id));
    final user = widget.isGuest ? null : await ApiService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _event = Event.fromJson(data);
        // FIX: only update _qrCode if the API actually returned one,
        // never set it to null (which was causing the QR to vanish)
        final freshQr = data['qr_code']?.toString();
        if (freshQr != null && freshQr.isNotEmpty) {
          _qrCode = freshQr;
        }
      }
      _isCreator = user != null && user['id'].toString() == _event.organizerId;
      _loading = false;
    });
  }

  Future<void> _register() async {
    if (widget.isGuest) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserLoginScreen()),
      );
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
    final text =
        'Join ${_event.title} on Zynkup: https://zynkup.app/events/${_event.id}';
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Event link copied.');
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
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 260,
                  backgroundColor: ZynkColors.darkSurface,
                  actions: [
                    IconButton(
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                    if (_isCreator)
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QrScannerScreen(event: _event),
                          ),
                        ),
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
                        const SizedBox(height: 12),
                        Text(
                          _event.title,
                          style: const TextStyle(
                            color: ZynkColors.darkText,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$joined student${joined == 1 ? '' : 's'} joined',
                          style: const TextStyle(
                            color: ZynkColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
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
                          style: const TextStyle(
                            color: ZynkColors.darkMuted,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: ZynkButton(
                                label: widget.isGuest
                                    ? 'Login to participate'
                                    : 'Register',
                                icon: Icons.how_to_reg_rounded,
                                isLoading: _registering,
                                onTap: _register,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ZynkButton(
                                label: 'Share',
                                icon: Icons.ios_share_rounded,
                                outlined: true,
                                onTap: _share,
                              ),
                            ),
                          ],
                        ),
                        // FIX: QR is now persistent — shown whenever _qrCode is non-null
                        if (_qrCode != null) ...[
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
                      ],
                    ),
                  ),
                ),
              ],
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
      );
    }
    return Image.network(
      image,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: BoxDecoration(
          gradient: ZynkGradients.forCategory(event.category.name),
        ),
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: ZynkColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ZynkColors.darkMuted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: ZynkColors.darkText,
                    fontWeight: FontWeight.w800,
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

class _QrPass extends StatelessWidget {
  const _QrPass({required this.qrCode});
  final String qrCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZynkColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Text(
            'Your QR Pass',
            style: TextStyle(
              color: ZynkColors.darkText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          QrImageView(data: qrCode, size: 190, backgroundColor: Colors.white),
        ],
      ),
    );
  }
}