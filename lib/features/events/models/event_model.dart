import 'package:zynkup/core/utils/date_utils.dart';

enum EventCategory { tech, cultural, sports, workshop, seminar }

enum RegistrationUrlType { googleForm, customUrl }

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    this.college,
    required this.date,
    required this.category,
    required this.organizerId,
    this.registeredUsers = const [],
    this.imageUrls = const [],
    this.isApproved = true,
    this.approvedAt,
    this.registrationUrl,
    this.registrationUrlType,
    this.attendeeCount = 0,
    this.galleryCount = 0,
    this.isRegistered = false,
    this.qrCode,
    this.canManage = false,
    this.isCoHost = false,
  });

  final String id;
  final String title;
  final String description;
  final String venue;
  final String? college;
  final DateTime date;
  final EventCategory category;
  final String organizerId;
  final List<String> registeredUsers;
  final List<String> imageUrls;
  final bool isApproved;
  final DateTime? approvedAt;
  final String? registrationUrl;
  final RegistrationUrlType? registrationUrlType;
  final int attendeeCount;
  final int galleryCount;
  final bool isRegistered;
  final String? qrCode;
  final bool canManage;
  final bool isCoHost;

  bool get isInterCollege {
    final c = college?.trim() ?? '';
    return c.contains(' vs ') || c.contains(' × ') || c.contains(' x ');
  }

  String get matchupType {
    final c = college?.trim() ?? '';
    if (c.contains(' vs ')) return 'vs';
    if (c.contains(' × ') || c.contains(' x ')) return '×';
    return '';
  }

  List<String> get interColleges {
    final c = college?.trim() ?? '';
    if (c.contains(' vs ')) {
      return c.split(' vs ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    if (c.contains(' × ')) {
      return c.split(' × ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    if (c.contains(' x ')) {
      return c.split(' x ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return c.isNotEmpty ? [c] : [];
  }

  static String extractShortCollegeName(String fullName) {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(fullName);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    if (fullName.length > 20) {
      return '${fullName.substring(0, 17)}...';
    }
    return fullName;
  }

  String get shortMatchupLabel {
    if (!isInterCollege) return college ?? '';
    final list = interColleges;
    if (list.length >= 2) {
      final a = extractShortCollegeName(list[0]);
      final b = extractShortCollegeName(list[1]);
      final sep = matchupType == 'vs' ? 'vs' : '×';
      final icon = matchupType == 'vs' ? '⚔️' : '🤝';
      return '$icon $a $sep $b';
    }
    return college ?? '';
  }

  bool userCanManage(Map<String, dynamic>? currentUser) {
    if (currentUser == null) return false;
    final userId = currentUser['id']?.toString();
    if (userId != null && userId == organizerId) return true;
    if (canManage) return true;
    if (isInterCollege) {
      final userCollege = (currentUser['college'] as String?)?.trim().toLowerCase() ?? '';
      if (userCollege.isNotEmpty) {
        for (final c in interColleges) {
          final cLow = c.toLowerCase();
          final shortName = extractShortCollegeName(c).toLowerCase();
          if (cLow.contains(userCollege) ||
              userCollege.contains(cLow) ||
              userCollege == shortName ||
              userCollege.contains(shortName)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final registered = _parseStringList(
      json['registeredUsers'] ?? json['registered_users'],
    );
    return Event(
      id: json['id'].toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      venue: (json['venue'] ?? '').toString(),
      college: json['college']?.toString(),
      date: ZynkDateUtils.parseUtc(json['date']) ?? DateTime.now(),
      category: _parseCategory(json['category']),
      organizerId:
          (json['organizerId'] ??
                  json['organizer_id'] ??
                  json['created_by'] ??
                  '')
              .toString(),
      registeredUsers: registered,
      imageUrls: _parseStringList(
        json['image_urls'] ?? json['images'] ?? json['image'],
      ),
      isApproved: json['isApproved'] ?? json['is_approved'] ?? true,
      approvedAt: ZynkDateUtils.parseUtc(json['approvedAt'] ?? json['approved_at']),
      registrationUrl: json['registration_url']?.toString(),
      registrationUrlType: _parseUrlType(json['registration_url_type']),
      attendeeCount: _parseInt(json['attendee_count']) ?? registered.length,
      galleryCount: _parseInt(json['gallery_count']) ?? 0,
      isRegistered: json['is_registered'] == true,
      qrCode: json['qr_code']?.toString(),
      canManage: json['can_manage'] == true || json['canManage'] == true,
      isCoHost: json['is_co_host'] == true || json['isCoHost'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'venue': venue,
    'college': college,
    'date': date.toIso8601String(),
    'category': category.name,
    'organizerId': organizerId,
    'registeredUsers': registeredUsers,
    'image_urls': imageUrls,
    'isApproved': isApproved,
    'approvedAt': approvedAt?.toIso8601String(),
    'registration_url': registrationUrl,
    'registration_url_type': registrationUrlType?.name,
    'attendee_count': attendeeCount,
    'gallery_count': galleryCount,
    'is_registered': isRegistered,
    'qr_code': qrCode,
    'can_manage': canManage,
    'is_co_host': isCoHost,
  };

  static EventCategory _parseCategory(dynamic value) {
    final raw = value?.toString().toLowerCase().trim() ?? 'tech';
    return EventCategory.values.firstWhere(
      (category) => category.name == raw,
      orElse: () => EventCategory.tech,
    );
  }

  static RegistrationUrlType? _parseUrlType(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    return RegistrationUrlType.values.cast<RegistrationUrlType?>().firstWhere(
      (type) => type?.name == raw,
      orElse: () => null,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return value
        .toString()
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
