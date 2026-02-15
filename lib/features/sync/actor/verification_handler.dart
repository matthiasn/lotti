import 'dart:async';

import 'package:matrix/encryption/utils/key_verification.dart';

typedef VerificationStateSink = void Function(Map<String, Object?> event);

class _VerificationState {
  _VerificationState(this.direction, this.verification)
      : previousOnUpdate = verification.onUpdate;

  final String direction;
  final KeyVerification verification;

  String? lastStep;
  bool? lastDone;
  bool? lastCanceled;
  String? lastEmojis;
  void Function()? previousOnUpdate;
}

/// Tracks outgoing and incoming key-verification flows for the actor.
class VerificationHandler {
  VerificationHandler({
    required VerificationStateSink onStateChanged,
    this.pollInterval = const Duration(milliseconds: 100),
  }) : _onStateChanged = onStateChanged;

  final VerificationStateSink _onStateChanged;
  final Duration pollInterval;

  _VerificationState? _outgoing;
  _VerificationState? _incoming;

  Timer? _pollTimer;

  bool get hasIncoming => _incoming != null;
  bool get hasOutgoing => _outgoing != null;

  /// Tracks an incoming verification request.
  void trackIncoming(KeyVerification verification) {
    _track(verification, 'incoming');
  }

  /// Tracks an outgoing verification request.
  void trackOutgoing(KeyVerification verification) {
    _track(verification, 'outgoing');
  }

  /// Returns a compact snapshot suitable for getVerificationState responses.
  Map<String, Object?> snapshot() {
    final incoming = _incoming;
    final outgoing = _outgoing;

    return <String, Object?>{
      'hasOutgoing': outgoing != null,
      'hasIncoming': incoming != null,
      'outgoingStep': outgoing?.verification.lastStep,
      'incomingStep': incoming?.verification.lastStep,
      'outgoingEmojis': _safeEmojisFor(outgoing?.verification),
      'incomingEmojis': _safeEmojisFor(incoming?.verification),
      'outgoingDone': outgoing?.verification.isDone ?? false,
      'incomingDone': incoming?.verification.isDone ?? false,
      'outgoingCanceled': outgoing?.verification.canceled ?? false,
      'incomingCanceled': incoming?.verification.canceled ?? false,
    };
  }

  Future<void> acceptVerification() async {
    final incoming = _incoming;
    if (incoming == null) {
      throw StateError('No incoming verification to accept');
    }

    await incoming.verification.acceptVerification();
  }

  Future<void> acceptSas() async {
    final target = _outgoing ?? _incoming;
    if (target == null) {
      throw StateError('No active verification for acceptSas');
    }

    await target.verification.acceptSas();
  }

  Future<void> cancel() async {
    final outgoing = _outgoing;
    final incoming = _incoming;

    _incoming = null;
    _outgoing = null;

    final futures = <Future<void>>[];
    if (incoming != null) {
      futures.add(incoming.verification.cancel());
      _restoreOnUpdate(incoming);
    }
    if (outgoing != null) {
      futures.add(outgoing.verification.cancel());
      _restoreOnUpdate(outgoing);
    }

    _pollTimer?.cancel();
    _pollTimer = null;
    await Future.wait(futures);
  }

  /// Disposes active handlers and suppresses periodic polling.
  Future<void> dispose() async {
    final outgoing = _outgoing;
    final incoming = _incoming;

    _incoming = null;
    _outgoing = null;
    _pollTimer?.cancel();
    _pollTimer = null;

    _restoreOnUpdate(incoming);
    _restoreOnUpdate(outgoing);

    await Future.wait(
      [
        if (incoming?.verification != null) incoming!.verification.cancel(),
        if (outgoing?.verification != null) outgoing!.verification.cancel(),
      ],
    );
  }

  void _track(KeyVerification verification, String direction) {
    final state = _VerificationState(direction, verification);
    if (direction == 'incoming') {
      _restoreOnUpdate(_incoming);
      _incoming = state;
    } else {
      _restoreOnUpdate(_outgoing);
      _outgoing = state;
    }

    _attachStateEmitter(state);
    _pollAll(forceEmit: true);
    _ensurePolling();
  }

  void _ensurePolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(pollInterval, (_) {
      _pollAll();
    });
  }

  void _pollAll({bool forceEmit = false}) {
    final remainingIncoming = _incoming;
    final remainingOutgoing = _outgoing;

    _emitIfChanged(remainingIncoming, forceEmit: forceEmit);
    _emitIfChanged(remainingOutgoing, forceEmit: forceEmit);

    if (_incoming == null && _outgoing == null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _emitIfChanged(_VerificationState? state, {bool forceEmit = false}) {
    if (state == null) {
      return;
    }

    final verification = state.verification;
    final currentStep = verification.lastStep;
    final currentDone = verification.isDone;
    final currentCanceled = verification.canceled;
    final emojiKey = _computeEmojiKey(verification);

    final changed = forceEmit ||
        state.lastStep != currentStep ||
        state.lastDone != currentDone ||
        state.lastCanceled != currentCanceled ||
        state.lastEmojis != emojiKey;

    if (!changed) {
      return;
    }

    state
      ..lastStep = currentStep
      ..lastDone = currentDone
      ..lastCanceled = currentCanceled
      ..lastEmojis = emojiKey;

    _onStateChanged(<String, Object?>{
      'event': 'verificationState',
      'direction': state.direction,
      'step': currentStep,
      'emojis': _safeEmojisFor(verification),
      'isDone': currentDone,
      'isCanceled': currentCanceled,
    });

    if (currentDone || currentCanceled) {
      if (state.direction == 'incoming') {
        _restoreOnUpdate(_incoming);
        _incoming = null;
      } else {
        _restoreOnUpdate(_outgoing);
        _outgoing = null;
      }
    }
  }

  void _attachStateEmitter(_VerificationState state) {
    final previous = state.previousOnUpdate;
    state.verification.onUpdate = () {
      previous?.call();
      _pollAll();
    };
  }

  void _restoreOnUpdate(_VerificationState? state) {
    if (state == null) return;

    state.verification.onUpdate = state.previousOnUpdate;
    state.previousOnUpdate = null;
  }

  static List<String> _serializeEmojis(List<KeyVerificationEmoji>? emojis) {
    return (emojis ?? const <KeyVerificationEmoji>[])
        .map(
          (emoji) => emoji.emoji,
        )
        .toList(growable: false);
  }

  static List<String> _safeEmojisFor(KeyVerification? verification) {
    if (verification == null) {
      return const <String>[];
    }
    final step = verification.lastStep;
    if (step != 'm.key.verification.key') {
      return const <String>[];
    }
    try {
      return _serializeEmojis(verification.sasEmojis);
    } catch (_) {
      return const <String>[];
    }
  }

  static String _computeEmojiKey(KeyVerification verification) {
    return _safeEmojisFor(verification).join('|');
  }
}
