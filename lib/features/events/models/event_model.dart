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

  // ── NEW: Registration QR fields ───────────────────
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

  // ================= FROM JSON =================
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      venue: json['venue'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      category: _parseCategory(json['category']),
      organizerId: json['organizerId'] ?? '',
      registeredUsers: List<String>.from(json['registeredUsers'] ?? []),
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      isApproved: json['isApproved'] ?? false,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'])
          : null,
      registrationUrl: json['registration_url'],
      registrationUrlType: _parseUrlType(json['registration_url_type']),
    );
  }

  // ================= TO JSON =================
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "description": description,
      "venue": venue,
      "date": date.toIso8601String(),
      "category": category.name,
      "organizerId": organizerId,
      "registeredUsers": registeredUsers,
      "image_urls": imageUrls,
      "isApproved": isApproved,
      "approvedAt": approvedAt?.toIso8601String(),
      "registration_url": registrationUrl,
      "registration_url_type": registrationUrlType?.name,
    };
  }

  // ================= COPY WITH =================
  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? venue,
    DateTime? date,
    EventCategory? category,
    String? organizerId,
    List<String>? registeredUsers,
    List<String>? imageUrls,
    bool? isApproved,
    DateTime? approvedAt,
    String? registrationUrl,
    RegistrationUrlType? registrationUrlType,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      venue: venue ?? this.venue,
      date: date ?? this.date,
      category: category ?? this.category,
      organizerId: organizerId ?? this.organizerId,
      registeredUsers: registeredUsers ?? this.registeredUsers,
      imageUrls: imageUrls ?? this.imageUrls,
      isApproved: isApproved ?? this.isApproved,
      approvedAt: approvedAt ?? this.approvedAt,
      registrationUrl: registrationUrl ?? this.registrationUrl,
      registrationUrlType: registrationUrlType ?? this.registrationUrlType,
    );
  }

  // ================= PARSERS =================
  static EventCategory _parseCategory(dynamic value) {
    if (value == null) return EventCategory.tech;
    try {
      return EventCategory.values.firstWhere((e) => e.name == value.toString());
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