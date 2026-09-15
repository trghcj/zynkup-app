import 'package:zynkup/core/widgets/zynk_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/theme/theme_provider.dart';
import 'package:zynkup/core/widgets/zynk_toast.dart';
import 'package:zynkup/core/widgets/login_prompt_sheet.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/features/events/models/event_model.dart';
import 'package:zynkup/features/events/screens/event_gallery_screen.dart';
import 'package:zynkup/features/events/screens/qr_scanner_screen.dart';
import 'package:zynkup/core/widgets/full_screen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynkup/features/events/screens/event_participants_screen.dart';
import 'package:zynkup/features/events/widgets/edit_event_sheet.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    required Event this.event,
    this.isGuest = false,
  }) : eventId = null;

  const EventDetailsScreen.fromId({
    super.key,
    required int this.eventId,
    this.isGuest = false,
  }) : event = null;

  final Event? event;
  final int? eventId;
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
  bool _isSaved = false;

  void _toggleSave() {
    setState(() => _isSaved = !_isSaved);
    _snack(_isSaved ? 'Event saved to bookmarks.' : 'Event removed from bookmarks.');
  }


  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _event = widget.event!;
      _qrCode = widget.event!.qrCode;
    } else {
      _event = Event(
        id: (widget.eventId ?? 0).toString(),
        title: 'Event Details',
        description: '',
        venue: '',
        date: DateTime.now(),
        category: EventCategory.tech,
        organizerId: '',
      );
    }
    _load();
    ApiService.eventUpdated.addListener(_onEventUpdated);
  }

  void _onEventUpdated() {
    final updated = ApiService.eventUpdated.value;
    if (updated != null && mounted && updated['id'].toString() == _event.id) {
      setState(() {
        _event = Event.fromJson(updated);
      });
    }
  }

  @override
  void dispose() {
    ApiService.eventUpdated.removeListener(_onEventUpdated);
    super.dispose();
  }

  Future<void> _load() async {
    final targetId = widget.eventId ?? int.tryParse(_event.id);
    if (targetId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final data = await ApiService.getEventById(targetId);
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
      ZToast.showSuccess(context, 'Registered', subtitle: 'You\'re on the guest list.');
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
    final shareUrl = '$baseUrl/events/${_event.id}';
    final text = 'Join "${_event.title}" on Zynkup:\n$shareUrl';
    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      _snack('Event link copied.');
    }
  }

  Future<void> _editEvent() async {
    final updatedData = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditEventSheet(event: _event),
    );
    if (updatedData != null && mounted) {
      setState(() {
        _event = Event.fromJson(updatedData);
      });
      _load();
    }
  }

  Future<void> _deleteEvent() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? ZynkColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZynkRadius.xl),
          side: BorderSide(
            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        title: Text(
          'Delete event?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'This will permanently remove "${_event.title}" and all registrations.',
          style: TextStyle(
            color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
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

    final deleted = await ApiService.deleteEvent(int.parse(_event.id));
    if (!mounted) return;
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

  void _showFormQrDialog(BuildContext context, String formUrl) {
    final isDark = themeProvider.isDark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? ZynkColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? ZynkColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Form QR',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0E1117),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? ZynkColors.darkMuted : const Color(0xFF94A3B8),
                size: 20,
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                'Scan this QR code with your phone camera, or click the button below to open the form directly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // QR Code Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: formUrl,
                  size: 200,
                ),
              ),
              const SizedBox(height: 24),
              // Primary "Click to Fill the Form" button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? ZynkColors.primary : const Color(0xFF0E1117),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    launchUrl(Uri.parse(formUrl), mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Click to Fill the Form',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Secondary "Copy Link" button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: formUrl));
                    if (context.mounted) {
                      ZToast.showSuccess(context, 'Link Copied', subtitle: 'Form link copied to clipboard.');
                    }
                  },
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                  ),
                  label: Text(
                    'Copy Form Link',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = _event.date.year == now.year && _event.date.month == now.month && _event.date.day == now.day;
    final isSoon = _event.date.difference(now).inDays > 0 && _event.date.difference(now).inDays <= 3;
    final isPast = _event.date.isBefore(now) && !isToday;
    
    String urgencyLabel = '';
    Color urgencyColor = ZynkColors.darkMuted;
    
    if (isToday) {
      urgencyLabel = 'Happening Today';
      urgencyColor = ZynkColors.error;
    } else if (isSoon) {
      urgencyLabel = 'Starts Soon';
      urgencyColor = ZynkColors.primary;
    } else if (isPast) {
      urgencyLabel = 'Past Event';
      urgencyColor = ZynkColors.darkMuted;
    }

    final joined = _event.attendeeCount > 0
        ? _event.attendeeCount
        : _event.registeredUsers.length;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ZynkBackground(
        child: _loading
            ? const _EventDetailsSkeleton()
            : CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 280,
              backgroundColor: Theme.of(context).colorScheme.surface,
              leading: Center(
                child: Container(
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  ),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: IconButton(
                    onPressed: _toggleSave,
                    icon: Icon(
                      _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 20,
                      color: _isSaved ? ZynkColors.primary : Theme.of(context).colorScheme.onSurface,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: IconButton(
                    onPressed: _share,
                    icon: Icon(
                      Icons.ios_share_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  ),
                ),
                if (_event.registrationUrl != null && _event.registrationUrl!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: IconButton(
                      tooltip: 'Event Form & QR',
                      onPressed: () => _showFormQrDialog(context, _event.registrationUrl!),
                      icon: const Icon(
                        Icons.assignment_outlined,
                        size: 20,
                        color: ZynkColors.primary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    ),
                  ),
                if (_isCreator) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: _openScanner,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 4, right: 12, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      color: Theme.of(context).colorScheme.surface,
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editEvent();
                        } else if (value == 'participants') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventParticipantsScreen(
                                eventId: _event.id,
                                eventTitle: _event.title,
                              ),
                            ),
                          );
                        } else if (value == 'delete') {
                          _deleteEvent();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
                              const SizedBox(width: 12),
                              Text('Edit Event', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'participants',
                          child: Row(
                            children: [
                              Icon(Icons.people_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
                              const SizedBox(width: 12),
                              Text('View Participants', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, color: ZynkColors.error, size: 20),
                              SizedBox(width: 12),
                              Text('Delete Event', style: TextStyle(color: ZynkColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(width: 8),
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
                        Row(
                          children: [
                            CategoryBadge(_event.category.name),
                            if (urgencyLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: urgencyColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  urgencyLabel,
                                  style: TextStyle(color: urgencyColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _event.title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
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
                        if (_event.college != null && _event.college!.isNotEmpty)
                          _Info(
                            icon: Icons.account_balance_rounded,
                            label: 'College / University',
                            value: _event.college!,
                          ),
                        const SizedBox(height: 22),
                         Text(
                          'About',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _event.description,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                            height: 1.6,
                            fontSize: 14,
                          ),
                        ),
                        if (_event.registrationUrl != null && _event.registrationUrl!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _FormCard(
                            formUrl: _event.registrationUrl!,
                            onTap: () => _showFormQrDialog(context, _event.registrationUrl!),
                          ),
                        ],
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
                      ],
                    ),
                  ),
                ),
              ],
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
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
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
            child: CachedNetworkImage(imageUrl: image,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              errorWidget: (_, __, ___) => Container(
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
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ZynkRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
            flex: 3,
            child: ZynkButton(
              label: 'Scan Attendance',
              icon: Icons.qr_code_scanner_rounded,
              onTap: onScan,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
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
          flex: 3,
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
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ZynkRadius.xl),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
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
               Text(
                'Your QR Pass',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailsSkeleton extends StatelessWidget {
  const _EventDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          pinned: true,
          expandedHeight: 280,
          backgroundColor: ZynkColors.darkSurface,
          flexibleSpace: FlexibleSpaceBar(
            background: ZSkeleton(width: double.infinity, height: 280, borderRadius: 0),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ZSkeleton(width: 80, height: 24),
                const SizedBox(height: 16),
                const ZSkeleton(width: 280, height: 32),
                const SizedBox(height: 12),
                const ZSkeleton(width: 140, height: 20),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const ZSkeleton(width: 40, height: 40, isCircle: true),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ZSkeleton(width: 120, height: 16),
                        SizedBox(height: 6),
                        ZSkeleton(width: 80, height: 12),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const ZSkeleton(width: double.infinity, height: 80, borderRadius: 12),
                const SizedBox(height: 32),
                const ZSkeleton(width: 100, height: 24),
                const SizedBox(height: 12),
                const ZSkeleton(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                const ZSkeleton(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                const ZSkeleton(width: 200, height: 16),
              ],
            ),
          ),
        )
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final String formUrl;
  final VoidCallback onTap;

  const _FormCard({required this.formUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.isDark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? ZynkColors.primary.withValues(alpha: 0.3)
                : const Color(0xFFBFDBFE),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? ZynkColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Form & QR Code',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0E1117),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Click to view QR code or fill out the form',
                    style: TextStyle(
                      color: isDark ? ZynkColors.darkMuted : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? ZynkColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 16,
                    color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Open',
                    style: TextStyle(
                      color: isDark ? ZynkColors.primary : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
