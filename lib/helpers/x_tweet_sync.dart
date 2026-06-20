// lib/helpers/x_tweet_sync.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class XTweeterSync {
  static Future<int> syncTweets() async {
    try {
      // ✅ Juiste endpoint:
      const endpoint =
          'https://europe-west1-derde-divisie-app.cloudfunctions.net/xSyncNow';

      print('🔗 Sync endpoint: $endpoint'); // <-- debugregel

      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['added'] ?? 0;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sync mislukt: $e');
    }
  }
}
