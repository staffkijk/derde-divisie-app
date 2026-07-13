import 'package:derde_divisie/data/services/activity_event_utils.dart';

class ActivityAnalyticsSummary {
  const ActivityAnalyticsSummary({
    required this.eventsToday,
    required this.eventsSevenDays,
    required this.uniqueUsers,
    required this.predictionsSaved,
    required this.logins,
    required this.screenViews,
    required this.activityPerDay,
    required this.eventDistribution,
    required this.screenViewsByName,
    required this.navigationByDestination,
    required this.predictionsByRound,
  });

  final int eventsToday;
  final int eventsSevenDays;
  final int uniqueUsers;
  final int predictionsSaved;
  final int logins;
  final int screenViews;
  final Map<String, int> activityPerDay;
  final Map<String, int> eventDistribution;
  final Map<String, int> screenViewsByName;
  final Map<String, int> navigationByDestination;
  final Map<String, int> predictionsByRound;
}

class ActivityAnalytics {
  const ActivityAnalytics._();

  static ActivityAnalyticsSummary summarize(
    List<ActivityLogEntry> events, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final todayStart = DateTime(current.year, current.month, current.day);
    final sevenDaysStart = todayStart.subtract(const Duration(days: 6));
    final users = <String>{};
    final perDay = <String, int>{
      for (var i = 0; i < 7; i++)
        _dayKey(sevenDaysStart.add(Duration(days: i))): 0,
    };
    final distribution = <String, int>{};
    final screens = <String, int>{};
    final navigation = <String, int>{};
    final rounds = <String, int>{};

    var today = 0;
    var sevenDays = 0;
    var predictions = 0;
    var logins = 0;
    var screenViews = 0;

    for (final event in events) {
      if (event.userId.trim().isNotEmpty) users.add(event.userId.trim());
      distribution[event.canonicalEventType] =
          (distribution[event.canonicalEventType] ?? 0) + 1;

      final createdAt = event.createdAt;
      if (createdAt != null) {
        final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
        if (!day.isBefore(todayStart)) today++;
        if (!day.isBefore(sevenDaysStart)) {
          sevenDays++;
          final key = _dayKey(day);
          if (perDay.containsKey(key)) perDay[key] = perDay[key]! + 1;
        }
      }

      if (event.canonicalEventType == ActivityEventKeys.predictionSaved) {
        predictions++;
        final round = event.metadata['round']?.toString();
        if (round != null && round.trim().isNotEmpty) {
          final key = 'Ronde ${round.trim()}';
          rounds[key] = (rounds[key] ?? 0) + 1;
        }
      }
      if (event.canonicalEventType == ActivityEventKeys.login) logins++;
      if (event.canonicalEventType == ActivityEventKeys.screenView) {
        screenViews++;
        final screen = event.metadata['screenName']?.toString() ??
            event.metadata['screen']?.toString() ??
            'Onbekend';
        screens[screen] = (screens[screen] ?? 0) + 1;
      }
      if (event.canonicalEventType == ActivityEventKeys.navigationClick) {
        final destination =
            event.metadata['destination']?.toString() ?? 'Onbekend';
        navigation[destination] = (navigation[destination] ?? 0) + 1;
      }
    }

    return ActivityAnalyticsSummary(
      eventsToday: today,
      eventsSevenDays: sevenDays,
      uniqueUsers: users.length,
      predictionsSaved: predictions,
      logins: logins,
      screenViews: screenViews,
      activityPerDay: Map.unmodifiable(perDay),
      eventDistribution: _sorted(distribution),
      screenViewsByName: _sorted(screens),
      navigationByDestination: _sorted(navigation),
      predictionsByRound: _sorted(rounds),
    );
  }

  static String _dayKey(DateTime day) {
    return '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}';
  }

  static Map<String, int> _sorted(Map<String, int> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.unmodifiable(
        {for (final entry in entries) entry.key: entry.value});
  }
}
