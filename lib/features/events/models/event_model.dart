enum EventCategory { tech, cultural, sports, workshop, seminar }

enum RegistrationUrlType { googleForm, customUrl }

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
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
  });

  final String id;
  final String title;
  final String description;
  final String venue;
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

  factory Event.fromJson(Map<String, dynamic> json) {
    final registered = _parseStringList(
      json['registeredUsers'] ?? json['registered_users'],
    );
    return Event(
      id: json['id'].toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      venue: (json['venue'] ?? '').toString(),
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
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
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : null,
      registrationUrl: json['registration_url']?.toString(),
      registrationUrlType: _parseUrlType(json['registration_url_type']),
      attendeeCount: _parseInt(json['attendee_count']) ?? registered.length,
      galleryCount: _parseInt(json['gallery_count']) ?? 0,
      isRegistered: json['is_registered'] == true,
      qrCode: json['qr_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'venue': venue,
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
