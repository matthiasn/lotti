import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';

void main() {
  group('TtsPlaybackState defaults', () {
    test('starts idle with empty progress and no source', () {
      const state = TtsPlaybackState();
      expect(state.status, TtsPlaybackStatus.idle);
      expect(state.sourceId, isNull);
      expect(state.downloadProgress, 0);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.errorMessage, isNull);
      expect(state.isBusy, isFalse);
    });
  });

  group('isBusy', () {
    test('is true while preparing or playing, false otherwise', () {
      bool busy(TtsPlaybackStatus s) => TtsPlaybackState(status: s).isBusy;
      expect(busy(TtsPlaybackStatus.downloadingModel), isTrue);
      expect(busy(TtsPlaybackStatus.synthesizing), isTrue);
      expect(busy(TtsPlaybackStatus.playing), isTrue);
      expect(busy(TtsPlaybackStatus.idle), isFalse);
      expect(busy(TtsPlaybackStatus.stopped), isFalse);
      expect(busy(TtsPlaybackStatus.error), isFalse);
    });
  });

  group('isActiveFor', () {
    test('matches only the busy source', () {
      const playingA = TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'task-a',
      );
      expect(playingA.isActiveFor('task-a'), isTrue);
      expect(playingA.isActiveFor('task-b'), isFalse);
    });

    test('is false when idle even if the source id lingers', () {
      const idleA = TtsPlaybackState(sourceId: 'task-a');
      expect(idleA.isActiveFor('task-a'), isFalse);
    });
  });

  group('copyWith', () {
    test('updates only the provided fields', () {
      const base = TtsPlaybackState(sourceId: 'task-a');
      final next = base.copyWith(
        status: TtsPlaybackStatus.synthesizing,
        downloadProgress: 0.4,
      );
      expect(next.status, TtsPlaybackStatus.synthesizing);
      expect(next.downloadProgress, 0.4);
      // Untouched fields are preserved.
      expect(next.sourceId, 'task-a');
    });

    test('can clear nullable fields back to null via the sentinel', () {
      const errored = TtsPlaybackState(
        status: TtsPlaybackStatus.error,
        sourceId: 'task-a',
        errorMessage: 'boom',
      );
      final cleared = errored.copyWith(
        status: TtsPlaybackStatus.idle,
        sourceId: null,
        errorMessage: null,
      );
      expect(cleared.sourceId, isNull);
      expect(cleared.errorMessage, isNull);
    });

    test('preserves nullable fields when not passed', () {
      const errored = TtsPlaybackState(
        sourceId: 'task-a',
        errorMessage: 'boom',
      );
      final next = errored.copyWith(position: const Duration(seconds: 1));
      expect(next.sourceId, 'task-a');
      expect(next.errorMessage, 'boom');
      expect(next.position, const Duration(seconds: 1));
    });
  });

  group('equality', () {
    test('compares by value', () {
      const a = TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'task-a',
      );
      const b = TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'task-a',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const TtsPlaybackState()));
    });
  });
}
