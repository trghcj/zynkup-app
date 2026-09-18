class ZynkDateUtils {
  /// Parses an ISO 8601 date string from the server.
  ///
  /// If the string does not specify a timezone (i.e. missing 'Z' or offset like '+00:00'),
  /// it treats it as UTC because backend timestamps in Postgres are stored in UTC,
  /// and then converts it to the user's local timezone.
  static DateTime? parseUtc(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return raw.isUtc ? raw.toLocal() : raw;
    }
    String str = raw.toString().trim();
    if (str.isEmpty || str == 'null') return null;

    // Check if timezone offset is missing (no Z, no +, and no trailing -HH:MM)
    if (!str.endsWith('Z') && !str.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(str)) {
      str = '${str}Z';
    }

    try {
      return DateTime.parse(str).toLocal();
    } catch (_) {
      try {
        return DateTime.tryParse(raw.toString())?.toLocal();
      } catch (_) {
        return null;
      }
    }
  }

  /// Formats a date or ISO string into human-friendly relative time:
  /// "just now", "5m ago", "2h ago", "3d ago", etc.
  static String formatTimeAgo(dynamic raw) {
    final dt = parseUtc(raw);
    if (dt == null) return 'some time ago';

    final now = DateTime.now();
    final diff = now.difference(dt);

    // If clock on device is slightly ahead of server or under 60 seconds
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '${weeks}w ago';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '${months}mo ago';
    }
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
  }
}
