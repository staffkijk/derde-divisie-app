class UserNotificationRecord {
  const UserNotificationRecord({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

List<String> missingPredictionNotificationIds(
  Iterable<UserNotificationRecord> notifications,
) =>
    notifications
        .where((item) => item.data['type'] == 'missing_predictions')
        .map((item) => item.id)
        .toList(growable: false);

int unreadNotificationCount(Iterable<UserNotificationRecord> notifications) =>
    notifications.where((item) => item.data['read'] != true).length;
