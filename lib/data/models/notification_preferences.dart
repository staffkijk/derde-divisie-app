import 'package:derde_divisie/data/config/season_config.dart';

enum NotificationTeamScope {
  all,
  favorite,
  selected,
}

class NotificationPreferences {
  const NotificationPreferences({
    this.missingPredictionReminders = true,
    this.divisionA = true,
    this.divisionB = true,
    this.teamScope = NotificationTeamScope.all,
    this.selectedTeamIds = const [],
  });

  final bool missingPredictionReminders;
  final bool divisionA;
  final bool divisionB;
  final NotificationTeamScope teamScope;
  final List<String> selectedTeamIds;

  factory NotificationPreferences.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const NotificationPreferences();
    return NotificationPreferences(
      // An absent value deliberately opts existing users in.
      missingPredictionReminders: data['missingPredictionReminders'] != false,
      divisionA: data['divisionA'] as bool? ?? true,
      divisionB: data['divisionB'] as bool? ?? true,
      teamScope: _teamScope(data['teamScope']),
      selectedTeamIds: (data['selectedTeamIds'] as List?)
              ?.map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList(growable: false) ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'missingPredictionReminders': missingPredictionReminders,
      'divisionA': divisionA,
      'divisionB': divisionB,
      'teamScope': teamScope.name,
      'selectedTeamIds': selectedTeamIds,
    };
  }

  NotificationPreferences copyWith({
    bool? missingPredictionReminders,
    bool? divisionA,
    bool? divisionB,
    NotificationTeamScope? teamScope,
    List<String>? selectedTeamIds,
  }) {
    return NotificationPreferences(
      missingPredictionReminders:
          missingPredictionReminders ?? this.missingPredictionReminders,
      divisionA: divisionA ?? this.divisionA,
      divisionB: divisionB ?? this.divisionB,
      teamScope: teamScope ?? this.teamScope,
      selectedTeamIds: selectedTeamIds ?? this.selectedTeamIds,
    );
  }

  bool allowsDivision(String division) {
    final normalized = SeasonConfig.normalizeDivisionCode(division);
    if (!missingPredictionReminders) return false;
    if (normalized == 'A') return divisionA;
    if (normalized == 'B') return divisionB;
    return true;
  }

  bool allowsMatchTeams({
    required String division,
    required Iterable<String> matchTeamIds,
    String? favoriteTeamId,
  }) {
    if (!allowsDivision(division)) return false;
    final teamIds = matchTeamIds.where((id) => id.trim().isNotEmpty).toSet();

    switch (teamScope) {
      case NotificationTeamScope.all:
        return true;
      case NotificationTeamScope.favorite:
        return favoriteTeamId != null && teamIds.contains(favoriteTeamId);
      case NotificationTeamScope.selected:
        return selectedTeamIds.any(teamIds.contains);
    }
  }

  static NotificationTeamScope _teamScope(Object? value) {
    final name = value?.toString();
    return NotificationTeamScope.values.firstWhere(
      (scope) => scope.name == name,
      orElse: () => NotificationTeamScope.all,
    );
  }
}

Map<String, dynamic> initialNotificationPreferences({
  required bool missingPredictionReminders,
}) =>
    NotificationPreferences(
      missingPredictionReminders: missingPredictionReminders,
    ).toMap();
