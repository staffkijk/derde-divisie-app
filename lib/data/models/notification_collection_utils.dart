import 'package:derde_divisie/data/config/season_config.dart';
import 'package:derde_divisie/data/models/notification_preferences.dart';

class UserNotificationRecord {
  const UserNotificationRecord({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

const predictionReminderNotificationTypes = {
  'missing_predictions',
  'missing_prediction',
  'missing-predictions',
  'missingPrediction',
  'prediction_reminder',
  'prediction_reminders',
  'prediction-reminder',
  'predictionReminder',
  'missingPredictions',
};

bool isMissingPredictionNotification(UserNotificationRecord notification) {
  final type = notification.data['type']?.toString();
  final title = notification.data['title']?.toString().trim();
  final body = notification.data['body']?.toString().toLowerCase() ?? '';
  final hasLegacyReminderCopy = title == 'Voorspellingen ontbreken' &&
      body.contains('wedstrijd') &&
      body.contains('niet voorspeld') &&
      body.contains('speelronde');
  return predictionReminderNotificationTypes.contains(type) ||
      notification.id.startsWith('missing_predictions_') ||
      notification.id.startsWith('missing-predictions_') ||
      hasLegacyReminderCopy;
}

bool isActiveMissingPredictionNotification(
  UserNotificationRecord notification,
) =>
    isMissingPredictionNotification(notification) &&
    (notification.data['read'] != true ||
        notification.data['resolved'] != true);

List<String> missingPredictionNotificationIds(
  Iterable<UserNotificationRecord> notifications,
) =>
    notifications
        .where(isActiveMissingPredictionNotification)
        .map((item) => item.id)
        .toList(growable: false);

int unreadNotificationCount(Iterable<UserNotificationRecord> notifications) =>
    notifications.where((item) => item.data['read'] != true).length;

String? predictionReminderDivision(UserNotificationRecord notification) {
  final stored = SeasonConfig.normalizeDivisionCode(
    notification.data['division']?.toString() ?? '',
  );
  if (stored == 'A' || stored == 'B') return stored;
  final idMatch =
      RegExp(r'missing[_-]predictions_[^_]+_([AB])_', caseSensitive: false)
          .firstMatch(notification.id);
  if (idMatch != null) return idMatch.group(1)!.toUpperCase();
  final title = (notification.data['title'] ?? '').toString();
  final body = (notification.data['body'] ?? '').toString();
  final copy = '$title $body'.toLowerCase();
  if (copy.contains('divisie a')) return 'A';
  if (copy.contains('divisie b')) return 'B';
  return null;
}

bool notificationAllowedByPreferences(
    UserNotificationRecord notification, NotificationPreferences preferences) {
  if (!isMissingPredictionNotification(notification)) return true;
  final division = predictionReminderDivision(notification);
  if (division != null) return preferences.allowsDivision(division);
  return preferences.allowsDivision('A') && preferences.allowsDivision('B');
}

List<UserNotificationRecord> notificationsAllowedByPreferences(
  Iterable<UserNotificationRecord> notifications,
  NotificationPreferences preferences,
) =>
    notifications
        .where((item) => notificationAllowedByPreferences(item, preferences))
        .toList(growable: false);

List<String> disallowedPredictionReminderNotificationIds(
  Iterable<UserNotificationRecord> notifications,
  NotificationPreferences preferences,
) =>
    notifications
        .where(isActiveMissingPredictionNotification)
        .where((item) => !notificationAllowedByPreferences(item, preferences))
        .map((item) => item.id)
        .toList(growable: false);
