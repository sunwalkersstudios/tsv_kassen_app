class Organization {
  final String id; // orgId (slug)
  final String name;
  final String adminEmail;
  final bool emailVerified;
  final DateTime? createdAt;

  Organization({
    required this.id,
    required this.name,
    required this.adminEmail,
    required this.emailVerified,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'adminEmail': adminEmail,
        'emailVerified': emailVerified,
        'createdAt': createdAt?.toIso8601String(),
      };

  static Organization fromMap(String id, Map<String, dynamic> m) => Organization(
        id: id,
        name: (m['name'] ?? '').toString(),
        adminEmail: (m['adminEmail'] ?? '').toString(),
        emailVerified: m['emailVerified'] == true,
        createdAt: m['createdAt'] is String ? DateTime.tryParse(m['createdAt']) : null,
      );
}
