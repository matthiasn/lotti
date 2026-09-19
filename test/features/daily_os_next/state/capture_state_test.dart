import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';

void main() {
  const listening = CaptureState(
    phase: CapturePhase.listening,
    transcript: '',
    amplitudes: [0.2, 0.6],
    dbfs: -32,
    audioId: 'audio-1',
  );

  group('CaptureState equality', () {
    test('compares amplitudes by content, not by list identity', () {
      final copy = CaptureState(
        phase: CapturePhase.listening,
        transcript: '',
        amplitudes: List.of(const [0.2, 0.6]),
        dbfs: -32,
        audioId: 'audio-1',
      );

      expect(copy, listening);
      expect(copy.hashCode, listening.hashCode);
    });

    test('every field participates', () {
      for (final changed in [
        listening.copyWith(phase: CapturePhase.transcribing),
        listening.copyWith(transcript: 'Walk the penguins'),
        listening.copyWith(amplitudes: const [0.2, 0.7]),
        listening.copyWith(dbfs: -31),
        listening.copyWith(audioId: 'audio-2'),
        listening.copyWith(error: CaptureError.noAudioRecorded),
      ]) {
        expect(changed, isNot(listening));
      }
    });
  });

  test('withoutMeter hides meter ticks so a select() on it stays quiet '
      'while the waveform moves', () {
    final louder = listening.copyWith(
      amplitudes: const [0.9, 0.95, 1],
      dbfs: -6,
    );

    expect(louder, isNot(listening));
    expect(louder.withoutMeter, listening.withoutMeter);
    expect(louder.withoutMeter.hashCode, listening.withoutMeter.hashCode);
    expect(louder.withoutMeter.amplitudes, isEmpty);
    expect(louder.withoutMeter.dbfs, CaptureState.defaultDbfs);
    // The non-meter fields survive the projection.
    expect(louder.withoutMeter.phase, CapturePhase.listening);
    expect(louder.withoutMeter.audioId, 'audio-1');
  });
}
