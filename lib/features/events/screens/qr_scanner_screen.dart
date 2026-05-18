import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, required this.event});
  final Event event;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _busy = false;
  String? _lastCode;
  final _manualController = TextEditingController();

  Future<void> _mark(String code) async {
    if (_busy || code == _lastCode) return;
    setState(() { _busy = true; _lastCode = code; });
    try {
      final result = await ApiService.markAttendance(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message']?.toString() ?? 'Attendance marked'),
        backgroundColor: ZynkColors.success,
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: ZynkColors.error,
      ));
    } finally {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) setState(() { _busy = false; _lastCode = null; });
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(title: Text('Scan ${widget.event.title}')),
      body: kIsWeb ? _webFallback() : _mobileScanner(),
    );
  }

  // ── Web: MobileScanner doesn't work on web — show manual QR code input ──
  Widget _webFallback() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner_rounded,
              color: ZynkColors.primary, size: 80),
          const SizedBox(height: 20),
          const Text(
            'QR scanning requires the mobile app.\n\nOn web, paste the attendee QR code manually:',
            textAlign: TextAlign.center,
            style: TextStyle(color: ZynkColors.darkMuted, height: 1.6),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: ZynkColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZynkColors.gold.withValues(alpha: 0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded, color: ZynkColors.gold, size: 16),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'You can only mark attendance for events you created.',
                    style: TextStyle(color: ZynkColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _manualController,
            decoration: const InputDecoration(
              labelText: 'Paste QR code here',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ZynkButton(
            label: _busy ? 'Marking...' : 'Mark Attendance',
            icon: Icons.check_circle_rounded,
            isLoading: _busy,
            onTap: () {
              final code = _manualController.text.trim();
              if (code.isEmpty) return;
              _mark(code);
            },
          ),
        ],
      ),
    );
  }

  // ── Mobile: real camera scanner ──
  Widget _mobileScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null && code.isNotEmpty) _mark(code);
          },
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(
                color: _busy ? ZynkColors.success : ZynkColors.primary,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _busy ? 'Marking attendance...' : 'Point camera at attendee QR pass',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}