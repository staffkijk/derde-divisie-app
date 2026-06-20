import 'package:cloud_firestore/cloud_firestore.dart';

class AppUpdate {
  final String id;
  final String version;
  final String title;
  final String body;
  final String type;
  final Timestamp? createdAt; // kan heel even null zijn

  AppUpdate({
    required this.id,
    required this.version,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
  });

  factory AppUpdate.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUpdate(
      id: doc.id,
      version: data['version'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'notice',
      createdAt: data['createdAt'], // kan null zijn totdat serverTimestamp gezet is
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': createdAt,
    };
  }
}
