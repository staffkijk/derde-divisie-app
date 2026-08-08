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
