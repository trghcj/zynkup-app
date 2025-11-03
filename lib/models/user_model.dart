class ZynkUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? department;
  final String? year;

  ZynkUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.department,
    this.year,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'department': department,
      'year': year,
    };
  }

  factory ZynkUser.fromMap(Map<String, dynamic> map) {
    return ZynkUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      department: map['department'],
      year: map['year'],
    );
  }
}
