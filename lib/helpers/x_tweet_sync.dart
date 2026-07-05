import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class XTweeterSync {
  static Future<int> syncTweets() async {
    try {
      const endpoint =
          'https://europe-west1-derde-divisie-app.cloudfunctions.net/xSyncNow';

      debugPrint('Sync endpoint: $endpoint');

      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['added'] ?? 0;
      }

      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      throw Exception('Sync mislukt: $e');
    }
  }
}
