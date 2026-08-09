import 'package:cloud_functions/cloud_functions.dart';

class ModeratorGa4Analytics {
  const ModeratorGa4Analytics({
    required this.visitorsToday,
    required this.visitorsSevenDays,
    required this.visitorsThirtyDays,
    required this.activeUsersNow,
    required this.sessionsThirtyDays,
    required this.newUsersThirtyDays,
    required this.returningUsersThirtyDays,
    required this.topPages,
    required this.deviceCategories,
    required this.trafficSources,
    this.configured = true,
    this.message,
  });

  final int visitorsToday;
  final int visitorsSevenDays;
  final int visitorsThirtyDays;
  final int activeUsersNow;
  final int sessionsThirtyDays;
  final int newUsersThirtyDays;
  final int returningUsersThirtyDays;
  final List<ModeratorGa4BreakdownItem> topPages;
  final List<ModeratorGa4BreakdownItem> deviceCategories;
  final List<ModeratorGa4BreakdownItem> trafficSources;
  final bool configured;
  final String? message;

  factory ModeratorGa4Analytics.notConfigured([String? message]) {
    return ModeratorGa4Analytics(
      visitorsToday: 0,
      visitorsSevenDays: 0,
      visitorsThirtyDays: 0,
      activeUsersNow: 0,
      sessionsThirtyDays: 0,
      newUsersThirtyDays: 0,
      returningUsersThirtyDays: 0,
      topPages: const [],
      deviceCategories: const [],
      trafficSources: const [],
      configured: false,
      message: message ?? 'GA4 rapportagedata nog niet geconfigureerd',
    );
  }

  factory ModeratorGa4Analytics.fromMap(Map<String, dynamic> data) {
    final configured = data['configured'] != false;
    if (!configured) {
      return ModeratorGa4Analytics.notConfigured(data['message']?.toString());
    }

    List<ModeratorGa4BreakdownItem> list(String key) {
      final value = data[key];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => ModeratorGa4BreakdownItem.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.label.isNotEmpty)
          .toList(growable: false);
    }

    return ModeratorGa4Analytics(
      visitorsToday: _int(data['visitorsToday']),
      visitorsSevenDays: _int(data['visitorsSevenDays']),
      visitorsThirtyDays: _int(data['visitorsThirtyDays']),
      activeUsersNow: _int(data['activeUsersNow']),
      sessionsThirtyDays: _int(data['sessionsThirtyDays']),
      newUsersThirtyDays: _int(data['newUsersThirtyDays']),
      returningUsersThirtyDays: _int(data['returningUsersThirtyDays']),
      topPages: list('topPages'),
      deviceCategories: list('deviceCategories'),
      trafficSources: list('trafficSources'),
      message: data['message']?.toString(),
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ModeratorGa4BreakdownItem {
  const ModeratorGa4BreakdownItem({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  factory ModeratorGa4BreakdownItem.fromMap(Map<String, dynamic> data) {
    return ModeratorGa4BreakdownItem(
      label: (data['label'] ?? '').toString(),
      value: ModeratorGa4Analytics._int(data['value']),
    );
  }
}

class ModeratorGa4AnalyticsService {
  ModeratorGa4AnalyticsService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<ModeratorGa4Analytics> load() async {
    try {
      final callable = _functions.httpsCallable('getModeratorGa4Analytics');
      final result = await callable.call<Map<String, dynamic>>();
      return ModeratorGa4Analytics.fromMap(
        Map<String, dynamic>.from(result.data),
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition') {
        return ModeratorGa4Analytics.notConfigured(error.message);
      }
      rethrow;
    }
  }
}
