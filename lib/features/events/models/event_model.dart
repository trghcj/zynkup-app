enum EventCategory {
  tech,
  cultural,
  sports,
  workshop,
  seminar,
}

enum RegistrationUrlType {
  googleForm,
  customUrl,
}

class Event {
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

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.date,
    required this.category,
    required this.organizerId,
    this.registeredUsers = const [],
    this.imageUrls = const [],
    this.isApproved = false,
    this.approvedAt,
    this.registrationUrl,
    this.registrationUrlType,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id:          json['id'].toString(),
      title:       json['title']       ?? '',
      description: json['description'] ?? '',
      venue:       json['venue']       ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      category:     _parseCategory(json['category']),
      organizerId:  json['organizerId']  ?? '',
      registeredUsers: List<String>.from(json['registeredUsers'] ?? []),

      // ✅ Handle BOTH formats:
      // 1. List<String>  → from new events.py _event_to_dict
      // 2. String (comma-separated) → from old EventResponse schema
      imageUrls: _parseImageUrls(json['image_urls']),

      isApproved: json['isApproved'] ?? json['is_approved'] ?? false,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'])
          : null,
      registrationUrl:     json['registration_url'],
      registrationUrlType: _parseUrlType(json['registration_url_type']),
    );
  }

  /// Handles List<dynamic>, String (comma-sep), or null
  static List<String> _parseImageUrls(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() => {
        "id":                    id,
        "title":                 title,
        "description":           description,
        "venue":                 venue,
        "date":                  date.toIso8601String(),
        "category":              category.name,
        "organizerId":           organizerId,
        "registeredUsers":       registeredUsers,
        "image_urls":            imageUrls,
        "isApproved":            isApproved,
        "approvedAt":            approvedAt?.toIso8601String(),
        "registration_url":      registrationUrl,
        "registration_url_type": registrationUrlType?.name,
      };

  Event copyWith({
    String? id, String? title, String? description,
    String? venue, DateTime? date, EventCategory? category,
    String? organizerId, List<String>? registeredUsers,
    List<String>? imageUrls, bool? isApproved, DateTime? approvedAt,
    String? registrationUrl, RegistrationUrlType? registrationUrlType,
  }) => Event(
        id:                    id              ?? this.id,
        title:                 title           ?? this.title,
        description:           description     ?? this.description,
        venue:                 venue           ?? this.venue,
        date:                  date            ?? this.date,
        category:              category        ?? this.category,
        organizerId:           organizerId     ?? this.organizerId,
        registeredUsers:       registeredUsers ?? this.registeredUsers,
        imageUrls:             imageUrls       ?? this.imageUrls,
        isApproved:            isApproved      ?? this.isApproved,
        approvedAt:            approvedAt      ?? this.approvedAt,
        registrationUrl:       registrationUrl ?? this.registrationUrl,
        registrationUrlType:   registrationUrlType ?? this.registrationUrlType,
      );

  static EventCategory _parseCategory(dynamic value) {
    if (value == null) return EventCategory.tech;
    try {
      return EventCategory.values
          .firstWhere((e) => e.name == value.toString());
    } catch (_) {
      return EventCategory.tech;
    }
  }

  static RegistrationUrlType? _parseUrlType(dynamic value) {
    if (value == null) return null;
    try {
      return RegistrationUrlType.values
          .firstWhere((e) => e.name == value.toString());
    } catch (_) {
      return null;
    }
  }
}