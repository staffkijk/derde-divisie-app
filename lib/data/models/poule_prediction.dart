class PoulePrediction {
  final String gebruikerId;
  final String wedstrijdId;
  final String scoreThuis;
  final String scoreUit;
  final int punten;

  PoulePrediction({
    required this.gebruikerId,
    required this.wedstrijdId,
    required this.scoreThuis,
    required this.scoreUit,
    required this.punten,
  });

  Map<String, dynamic> toMap() {
    return {
      'gebruikerId': gebruikerId,
      'wedstrijdId': wedstrijdId,
      'scoreThuis': scoreThuis,
      'scoreUit': scoreUit,
      'punten': punten,
    };
  }

  factory PoulePrediction.fromMap(Map<String, dynamic> map) {
    return PoulePrediction(
      gebruikerId: map['gebruikerId'],
      wedstrijdId: map['wedstrijdId'],
      scoreThuis: map['scoreThuis'],
      scoreUit: map['scoreUit'],
      punten: map['punten'] ?? 0,
    );
  }
}
