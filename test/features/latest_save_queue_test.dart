import 'dart:async';

import 'package:derde_divisie/features/voorspellen/latest_save_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending nieuwste volgorde wordt na mislukte eerste write opgeslagen',
      () async {
    final firstWrite = Completer<void>();
    final writes = <List<String>>[];
    final events = <String>[];
    var attempts = 0;

    final queue = LatestSaveQueue<List<String>>(
      write: (ranking) async {
        writes.add([...ranking]);
        attempts++;
        if (attempts == 1) await firstWrite.future;
      },
      onSavingChanged: (saving) => events.add('saving:$saving'),
      onAttemptStarted: () => events.add('attempt'),
      onAttemptSucceeded: () => events.add('saved'),
      onAttemptFailed: (error, stackTrace) => events.add('failed:$error'),
    );

    final save1 = queue.enqueue(['A', 'B', 'C']);
    expect(queue.isSaving, isTrue);
    expect(writes, [
      ['A', 'B', 'C'],
    ]);

    final save2 = queue.enqueue(['B', 'C', 'A']);
    expect(queue.hasPending, isTrue);
    firstWrite.completeError(StateError('permission-denied'));

    await Future.wait([save1, save2]);

    expect(writes, [
      ['A', 'B', 'C'],
      ['B', 'C', 'A'],
    ]);
    expect(events, [
      'saving:true',
      'attempt',
      'failed:Bad state: permission-denied',
      'attempt',
      'saved',
      'saving:false',
    ]);
    expect(queue.isSaving, isFalse);
    expect(queue.hasPending, isFalse);
  });

  test('laatste mislukte write eindigt zonder loop en kan opnieuw', () async {
    var shouldFail = true;
    final events = <String>[];
    final queue = LatestSaveQueue<List<String>>(
      write: (_) async {
        if (shouldFail) throw StateError('offline');
      },
      onSavingChanged: (saving) => events.add('saving:$saving'),
      onAttemptStarted: () => events.add('attempt'),
      onAttemptSucceeded: () => events.add('saved'),
      onAttemptFailed: (error, stackTrace) => events.add('failed'),
    );

    await queue.enqueue(['B', 'A']);
    expect(queue.isSaving, isFalse);
    expect(queue.hasPending, isFalse);
    expect(events.last, 'saving:false');

    shouldFail = false;
    await queue.enqueue(['B', 'A']);
    expect(events, contains('saved'));
    expect(queue.isSaving, isFalse);
  });
}
