import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Three discrete phases of the Capture screen.
enum CapturePhase {
  /// Nothing being recorded — soft hints visible.
  idle,

  /// Streaming a transcript. The voice button pulses, the live
  /// waveform animates, and the transcript fills in word-by-word.
  listening,

  /// Listening stopped. Transcript is finalised and the
  /// "Reconcile" affordance is enabled.
  captured,
}

/// State held by [CaptureController].
@immutable
class CaptureState {
  const CaptureState({
    required this.phase,
    required this.transcript,
  });

  const CaptureState.idle() : phase = CapturePhase.idle, transcript = '';

  final CapturePhase phase;

  /// Accumulating transcript text. Italicised while listening,
  /// solid once captured. Empty when idle.
  final String transcript;

  CaptureState copyWith({
    CapturePhase? phase,
    String? transcript,
  }) {
    return CaptureState(
      phase: phase ?? this.phase,
      transcript: transcript ?? this.transcript,
    );
  }
}

/// Drives the Capture screen's listening lifecycle.
///
/// While the real STT pipeline (`features/speech`) is wired in later,
/// the controller emits a scripted transcript so the UI loop is
/// demoable end-to-end. The scripted transcript is the same text the
/// `MockDayAgent` is designed to parse — so a tap-to-talk demo
/// produces a coherent Reconcile screen with NEW / MATCHED / UPDATE /
/// low-confidence cards.
///
/// Test seam: pass `transcriptChunks` + `chunkInterval` to control
/// the scripted stream deterministically (no real clock).
class CaptureController extends Notifier<CaptureState> {
  CaptureController({
    List<String>? transcriptChunks,
    this.chunkInterval = const Duration(milliseconds: 90),
  }) : _transcriptChunks =
           transcriptChunks ?? const _DefaultDemoTranscript().chunks;

  /// Words / phrases emitted in sequence during listening.
  final List<String> _transcriptChunks;

  /// Cadence between transcript chunks while listening.
  final Duration chunkInterval;

  Timer? _streamTimer;
  int _cursor = 0;

  @override
  CaptureState build() {
    ref.onDispose(_cancelTimer);
    return const CaptureState.idle();
  }

  /// Toggle between idle ⇄ listening ⇄ captured.
  /// - From `idle`: arm listening + start the scripted stream.
  /// - From `listening`: stop early, finalise the partial transcript.
  /// - From `captured`: reset back to idle.
  void toggle() {
    switch (state.phase) {
      case CapturePhase.idle:
        _beginListening();
      case CapturePhase.listening:
        _finishListening();
      case CapturePhase.captured:
        reset();
    }
  }

  /// Manual reset — used by the "Re-record" footer on Reconcile.
  void reset() {
    _cancelTimer();
    _cursor = 0;
    state = const CaptureState.idle();
  }

  void _beginListening() {
    _cursor = 0;
    state = const CaptureState(
      phase: CapturePhase.listening,
      transcript: '',
    );
    _streamTimer = Timer.periodic(chunkInterval, (timer) {
      if (_cursor >= _transcriptChunks.length) {
        timer.cancel();
        _finishListening();
        return;
      }
      final next = _transcriptChunks[_cursor++];
      final current = state.transcript;
      final joined = current.isEmpty
          ? next
          : '$current${_needsLeadingSpace(next) ? ' ' : ''}$next';
      state = state.copyWith(transcript: joined);
    });
  }

  void _finishListening() {
    _cancelTimer();
    state = state.copyWith(phase: CapturePhase.captured);
  }

  void _cancelTimer() {
    _streamTimer?.cancel();
    _streamTimer = null;
  }

  bool _needsLeadingSpace(String next) {
    // Punctuation chunks (',', '.', '?', etc.) attach without a leading space.
    if (next.isEmpty) return false;
    final first = next.codeUnitAt(0);
    const comma = 0x2C;
    const period = 0x2E;
    const question = 0x3F;
    const exclamation = 0x21;
    return first != comma &&
        first != period &&
        first != question &&
        first != exclamation;
  }
}

class _DefaultDemoTranscript {
  const _DefaultDemoTranscript();

  List<String> get chunks => const [
    'Need',
    'to',
    'send',
    'the',
    'deck',
    'to',
    'Sarah',
    'today',
    ',',
    'review',
    'invoices',
    'before',
    'eleven',
    ',',
    'did',
    'my',
    'run',
    'already',
    ',',
    'and',
    'call',
    'mom',
    'about',
    'Sunday',
    '.',
  ];
}

/// Creates a fresh controller per route entry so a re-entry into
/// Capture starts cleanly. The Reconcile screen reads the captured
/// transcript via the capture id handed off when navigating.
// ignore: specify_nonobvious_property_types
final captureControllerProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureState>(
      CaptureController.new,
    );
