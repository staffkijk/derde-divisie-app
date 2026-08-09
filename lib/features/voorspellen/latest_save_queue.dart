import 'dart:async';

/// Serialiseert writes en bewaart tijdens een lopende write alleen de nieuwste
/// aangeleverde waarde. Iedere pending waarde wordt maximaal één keer gestart.
class LatestSaveQueue<T extends Object> {
  LatestSaveQueue({
    required this.write,
    required this.onSavingChanged,
    required this.onAttemptStarted,
    required this.onAttemptSucceeded,
    required this.onAttemptFailed,
  });

  final Future<void> Function(T value) write;
  final void Function(bool saving) onSavingChanged;
  final void Function() onAttemptStarted;
  final void Function() onAttemptSucceeded;
  final void Function(Object error, StackTrace stackTrace) onAttemptFailed;

  T? _pending;
  Future<void>? _drainFuture;

  bool get isSaving => _drainFuture != null;
  bool get hasPending => _pending != null;

  Future<void> enqueue(T value) {
    _pending = value;
    return _drainFuture ??= _drain();
  }

  Future<void> _drain() async {
    onSavingChanged(true);
    try {
      while (_pending != null) {
        final value = _pending!;
        _pending = null;
        onAttemptStarted();
        try {
          await write(value);
          onAttemptSucceeded();
        } catch (error, stackTrace) {
          onAttemptFailed(error, stackTrace);
        }
      }
    } finally {
      _drainFuture = null;
      onSavingChanged(false);
    }
  }
}
