import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late final String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  group('Firestore security rules', () {
    test('hebben geen brede signed-in write fallback', () {
      expect(
        rules,
        isNot(
          contains(
            'match /{document=**} {\n'
            '      allow read: if true;\n'
            '      allow write: if signedIn();',
          ),
        ),
      );
      expect(rules, contains('allow read: if false;'));
      expect(rules, contains('allow write: if false;'));
    });

    test('beschermen moderator-rootcollecties server-side', () {
      for (final pattern in [
        'match /matches/{matchId}',
        'match /standen/{standingId}',
        'match /periodestanden/{document=**}',
        'match /sync_logs/{logId}',
        'match /voorspel_punten/{uid}',
      ]) {
        expect(rules, contains(pattern));
      }

      expect(rules, contains('allow write: if isModerator();'));
    });

    test('activity logs zijn alleen leesbaar voor moderators', () {
      expect(rules, contains('match /activityLogs/{logId}'));
      expect(rules, contains('allow read: if isModerator();'));
      expect(rules, contains('allow update, delete: if false;'));
    });

    test('poule en voorspelling writes blijven expliciet toegestaan', () {
      expect(rules, contains('match /poules/{pouleId}'));
      expect(
        rules,
        contains('request.resource.data.ownerId == request.auth.uid'),
      );
      expect(rules, contains('match /poule_predictions/{predictionId}'));
      expect(rules, contains('match /poule_voorspellingen/{predictionId}'));
      expect(rules, contains('match /predictions/{predictionId}'));
      expect(rules, contains('isNewPredictionOwner()'));
      expect(rules, contains('isExistingPredictionOwner()'));
    });

    test('gebruikers kunnen moderatorclaims niet zelf wijzigen', () {
      expect(rules, contains('hasNoModeratorClaims()'));
      expect(rules, contains('keepsModeratorClaimsUnchanged()'));
      expect(
        rules,
        contains("hasAny(['ismoderator', 'isModerator'])"),
      );
    });

    test('legacy eindstanddocument migreert alleen via de eigen vaste id', () {
      expect(
        rules,
        contains('isOwnerlessOwnEindstandDocument(predictionId)'),
      );
      expect(rules, contains("predictionId == request.auth.uid + '_A'"));
      expect(rules, contains("predictionId == request.auth.uid + '_B'"));
      expect(rules, contains("!('gebruikerId' in resource.data)"));
      expect(rules, contains("!('userId' in resource.data)"));
      expect(rules, contains("!('uid' in resource.data)"));
      expect(
        rules,
        contains(
          '(isExistingPredictionOwner() || isOwnerlessOwnEindstandDocument(predictionId))',
        ),
      );
    });
  });
}
