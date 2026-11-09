import 'package:url_launcher/url_launcher.dart';

/// Parses a user-supplied link and returns it only if it is a plain http(s)
/// URL with a host. Scheme-less links ("youtube.com/...") get https://.
///
/// Links come from other users (posts, events, chat), so anything else, such
/// as `javascript:`, `intent:`, `file:` or `data:`, is rejected rather than
/// handed to the OS or browser.
Uri? safeHttpUri(String? raw) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.isEmpty) return null;
  if (!value.contains('://')) {
    final lower = value.toLowerCase();
    const blocked = ['javascript:', 'data:', 'file:', 'intent:', 'vbscript:'];
    if (blocked.any(lower.startsWith)) return null;
    value = 'https://$value';
  }
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}

/// Opens [raw] only if [safeHttpUri] accepts it. Returns false otherwise.
Future<bool> launchSafeUrl(
  String? raw, {
  LaunchMode mode = LaunchMode.platformDefault,
}) async {
  final uri = safeHttpUri(raw);
  if (uri == null) return false;
  return launchUrl(uri, mode: mode);
}
