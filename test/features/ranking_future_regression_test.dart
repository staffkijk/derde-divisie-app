import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/features/voorspellen/ranking_screen.dart').readAsStringSync();
  test('users future wordt eenmaal in initState aangemaakt', () {
    expect(
        source,
        contains(
            'late final Future<QuerySnapshot<Map<String, dynamic>>> _usersFuture'));
    expect(RegExp(r"collection\('users'\)\.get\(\)").allMatches(source),
        hasLength(1));
    expect(source, contains('future: _usersFuture'));
  });
  test('zoeken filtert lokaal en behoudt echte rankingpositie', () {
    expect(source, contains('.contains(normalizedQuery)'));
    expect(source, contains('positions[user.id]'));
  });
}
