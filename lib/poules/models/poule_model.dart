// lib/poules/models/poule_model.dart

class Poule {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final bool isPublic;
  final String? password;
  final String competition; // 'dda', 'ddb', of 'team'
  final String? imageUrl;
  final DateTime createdAt;

  Poule({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.isPublic,
    required this.competition,
    required this.createdAt,
    this.password,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'isPublic': isPublic,
      'password': password,
      'competition': competition,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Poule.fromMap(Map<String, dynamic> map) {
    return Poule(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      ownerId: map['ownerId'],
      isPublic: map['isPublic'],
      password: map['password'],
      competition: map['competition'],
      imageUrl: map['imageUrl'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
