import 'package:flutter_test/flutter_test.dart';

import 'package:derde_divisie/features/moderator/prediction_processing_guard.dart';

void main() {
  group('prediction processing completion guard', () {
    test('volledige verwerking wordt geaccepteerd', () {
      expect(
        predictionProcessingIsComplete(
          selectedUsers: 56,
          processedUsers: 56,
        ),
        isTrue,
      );

      expect(
        () => ensureCompletePredictionProcessing(
          selectedUsers: 56,
          processedUsers: 56,
        ),
        returnsNormally,
      );
    });

    test('b_05_05 scenario 56 geselecteerd en 0 verwerkt faalt hard', () {
      expect(
        () => ensureCompletePredictionProcessing(
          selectedUsers: 56,
          processedUsers: 0,
        ),
        throwsA(
          isA<PredictionProcessingInvariantException>()
              .having((e) => e.selectedUsers, 'selectedUsers', 56)
              .having((e) => e.processedUsers, 'processedUsers', 0),
        ),
      );
    });

    test('gedeeltelijke verwerking mag niet als processed worden gemarkeerd', () {
      expect(
        predictionProcessingIsComplete(
          selectedUsers: 56,
          processedUsers: 55,
        ),
        isFalse,
      );
      expect(
        () => ensureCompletePredictionProcessing(
          selectedUsers: 56,
          processedUsers: 55,
        ),
        throwsA(isA<PredictionProcessingInvariantException>()),
      );
    });

    test('geen voorspellers is een complete 0-op-0 verwerking', () {
      expect(
        () => ensureCompletePredictionProcessing(
          selectedUsers: 0,
          processedUsers: 0,
        ),
        returnsNormally,
      );
    });
  });
}
