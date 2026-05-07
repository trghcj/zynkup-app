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

  Future<void> _mark(String code) async {
    if (_busy || code == _lastCode) return;
    setState(() {
      _busy = true;
      _lastCode = code;
    });
    try {
      final result = await ApiService.markAttendance(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Attendance marked'),
          backgroundColor: ZynkColors.success,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: ZynkColors.error,
        ),
      );
    } finally {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _busy = false;
          _lastCode = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      appBar: AppBar(title: Text('Scan ${widget.event.title}')),
      body: Stack(
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
                _busy
                    ? 'Marking attendance...'
                    : 'Point camera at attendee QR pass',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
