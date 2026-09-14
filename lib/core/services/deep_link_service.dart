import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zynkup/features/events/screens/event_details_screen.dart';
import 'package:zynkup/features/feed/screens/post_detail_screen.dart';

class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;
  static Uri? pendingUri;
  static GlobalKey<NavigatorState>? navigatorKey;
  static bool isAppReady = false;
  static String? _lastHandledKey;
  static DateTime? _lastHandledTime;

  static void configure(GlobalKey<NavigatorState> navKey) {
    navigatorKey = navKey;
  }

  static Future<void> init() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('DeepLinkService: Initial link received: $initialUri');
        pendingUri = initialUri;
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error getting initial link: $e');
    }

    if (kIsWeb) {
      try {
        final currentUri = Uri.base;
        if (currentUri.path.contains('/events/') ||
            currentUri.path.contains('/feed/') ||
            currentUri.path.contains('/posts/') ||
            currentUri.fragment.contains('/events/') ||
            currentUri.fragment.contains('/feed/') ||
            currentUri.fragment.contains('/posts/')) {
          debugPrint('DeepLinkService: Web currentUri: $currentUri');
          pendingUri = currentUri;
        }
      } catch (_) {}
    }

    _linkSubscription?.cancel();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('DeepLinkService: Stream link received: $uri');
        handleUri(uri);
      },
      onError: (err) {
        debugPrint('DeepLinkService: Link stream error: $err');
      },
    );
  }

  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }

  static bool checkAndHandlePendingLink([BuildContext? context]) {
    if (pendingUri == null) return false;
    final uri = pendingUri!;
    pendingUri = null;
    isAppReady = true;
    handleUri(uri, context: context);
    return true;
  }

  static void handleUri(Uri uri, {BuildContext? context}) {
    if (!isAppReady) {
      debugPrint('DeepLinkService: App not mounted yet, queueing pendingUri: $uri');
      pendingUri = uri;
      return;
    }

    String? type;
    String? idStr;

    if (uri.scheme == 'zynkup') {
      final host = uri.host.toLowerCase();
      if (host.isNotEmpty) {
        type = host;
        idStr = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
      } else if (uri.pathSegments.isNotEmpty) {
        type = uri.pathSegments[0].toLowerCase();
        idStr = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      }
    } else {
      final segments = uri.pathSegments;
      for (int i = 0; i < segments.length; i++) {
        final seg = segments[i].toLowerCase();
        if ((seg == 'events' || seg == 'feed' || seg == 'posts') &&
            i + 1 < segments.length) {
          type = seg;
          idStr = segments[i + 1];
          break;
        }
      }
    }

    if (type == null || idStr == null) {
      if (uri.fragment.isNotEmpty) {
        final frag = uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
        final fragUri = Uri.tryParse(frag);
        if (fragUri != null) {
          final segments = fragUri.pathSegments;
          for (int i = 0; i < segments.length; i++) {
            final seg = segments[i].toLowerCase();
            if ((seg == 'events' || seg == 'feed' || seg == 'posts') &&
                i + 1 < segments.length) {
              type = seg;
              idStr = segments[i + 1];
              break;
            }
          }
        }
      }
    }

    if (type == null || idStr == null) return;
    final id = int.tryParse(idStr);
    if (id == null) return;

    final routeKey = '$type/$id';
    final now = DateTime.now();
    if (_lastHandledKey == routeKey &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(milliseconds: 1500)) {
      debugPrint('DeepLinkService: Skipping duplicate navigation for $routeKey');
      return;
    }
    _lastHandledKey = routeKey;
    _lastHandledTime = now;

    final nav = navigatorKey?.currentState ??
        (context != null ? Navigator.of(context) : null);
    if (nav == null) {
      pendingUri = uri;
      return;
    }

    if (type == 'events') {
      nav.push(
        MaterialPageRoute(
          builder: (_) => EventDetailsScreen.fromId(eventId: id),
        ),
      );
    } else if (type == 'feed' || type == 'posts') {
      nav.push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: id),
        ),
      );
    }
  }
}
