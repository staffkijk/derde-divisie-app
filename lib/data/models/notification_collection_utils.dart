class UserNotificationRecord {
  const UserNotificationRecord({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

const predictionReminderNotificationTypes = {
  'missing_predictions',
  'missing_prediction',
  'prediction_reminder',
  'prediction_reminders',
  'missingPredictions',
};

bool isMissingPredictionNotification(UserNotificationRecord notification) {
  final type = notification.data['type']?.toString();
  return predictionReminderNotificationTypes.contains(type) ||
      notification.id.startsWith('missing_predictions_');
}

List<String> missingPredictionNotificationIds(
  Iterable<UserNotificationRecord> notifications,
) =>
    notifications
        .where(isMissingPredictionNotification)
        .map((item) => item.id)
        .toList(growable: false);

int unreadNotificationCount(Iterable<UserNotificationRecord> notifications) =>
    notifications.where((item) => item.data['read'] != true).length;
