import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

abstract class MatchDateTimeFormatter {
  static DateTime? dateTimeFromData(Map<String, dynamic> data) {
    final direct = _asDateTime(
      data['scheduledAt'] ??
          data['dateTime'] ??
          data['timestamp'] ??
          data['datum'] ??
          data['date'],
    );
    final time = timeFromData(data);
    if (direct == null || time == null) return direct;

    // scheduledAt en timestamps bevatten al een bewuste tijd.
    if (data['scheduledAt'] != null ||
        data['dateTime'] != null ||
        data['timestamp'] != null ||
        data['datum'] is Timestamp) {
      return direct;
    }

    final parts = time.split(':');
    return DateTime(
      direct.year,
      direct.month,
      direct.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static String? timeFromData(Map<String, dynamic> data) {
    final raw = data['kickoffTime'] ?? data['time'] ?? data['kickoff'];
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value)) return null;
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour > 23 ||
        minute > 59 ||
        hour < 0 ||
        minute < 0) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String dayHeader(DateTime date) {
    return DateFormat('EEEE d MMMM y', 'nl_NL').format(date);
  }

  static String shortDate(DateTime date) {
    return DateFormat('EEE d MMM', 'nl_NL').format(date);
  }

  static String publicTime(Map<String, dynamic> data) {
    final explicitTime = timeFromData(data);
    if (explicitTime != null) return explicitTime;
    final dateTime = dateTimeFromData(data);
    if (dateTime == null || (dateTime.hour == 0 && dateTime.minute == 0)) {
      return 'Tijd onbekend';
    }
    return DateFormat('HH:mm').format(dateTime);
  }

  static int compare(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    var result = _text(a['division']).compareTo(_text(b['division']));
    if (result != 0) return result;
    result = _int(a['round']).compareTo(_int(b['round']));
    if (result != 0) return result;

    final aDate = dateTimeFromData(a);
    final bDate = dateTimeFromData(b);
    if (aDate != null && bDate != null) {
      result = aDate.compareTo(bDate);
      if (result != 0) return result;
    } else if (aDate != null) {
      return -1;
    } else if (bDate != null) {
      return 1;
    }

    result = publicTime(a).compareTo(publicTime(b));
    if (result != 0) return result;
    result = _int(a['roundMatchIndex']).compareTo(_int(b['roundMatchIndex']));
    if (result != 0) return result;
    return _text(a['homeTeamName'] ?? a['homeTeam'])
        .compareTo(_text(b['homeTeamName'] ?? b['homeTeam']));
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value.trim());
    if (value is int) {
      final millis = value > 1000000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return null;
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 999;
  }

  static String _text(dynamic value) =>
      value?.toString().trim().toLowerCase() ?? '';
}
