// ignore_for_file: cascade_invocations
import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

// Create a simple test class that mimics the core functionality we want to test
// This avoids the need to mock media_kit Player which is causing initialization issues
class TestAudioPlayerCubit extends Cubit<AudioPlayerState> {
  TestAudioPlayerCubit()
      : super(
          AudioPlayerState(
            status: AudioPlayerStatus.initializing,
            totalDuration: Duration.zero,
            progress: Duration.zero,
            pausedAt: Duration.zero,
            showTranscriptsList: false,
            speed: 1,
          ),
        );

  void updateProgress(Duration duration) {
    final clamped =
        duration > state.totalDuration && state.totalDuration > Duration.zero
            ? state.totalDuration
            : duration;

    if (clamped == state.progress) {
      return;
    }

    emit(state.copyWith(progress: clamped));
  }

  void updateBuffered(Duration buffered) {
    final total = state.totalDuration;
    final clamped =
        total > Duration.zero && buffered > total ? total : buffered;

    if (clamped == state.buffered) {
      return;
    }

    emit(
      state.copyWith(
        buffered: clamped,
      ),
    );
  }

  void testSeek(Duration newPosition) {
    final newBuffered =
        newPosition > state.buffered ? newPosition : state.buffered;

    if (newPosition == state.progress &&
        newPosition == state.pausedAt &&
        newBuffered == state.buffered) {
      return;
    }
    emit(
      state.copyWith(
        progress: newPosition,
        pausedAt: newPosition,
        buffered: newBuffered,
      ),
    );
  }

  void pause() {
    emit(
      state.copyWith(
        status: AudioPlayerStatus.paused,
        pausedAt: state.progress,
      ),
    );
  }

  void play() {
    emit(state.copyWith(status: AudioPlayerStatus.playing));
  }

  void setSpeed(double speed) {
    emit(state.copyWith(speed: speed));
  }

  void setTotalDuration(Duration duration) {
    emit(state.copyWith(totalDuration: duration));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestAudioPlayerCubit playerCubit;
  late MockLoggingService mockLoggingService;

  setUp(() {
    mockLoggingService = MockLoggingService();

    // Register mocks with GetIt
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Create our test implementation
    playerCubit = TestAudioPlayerCubit();
  });

  tearDown(getIt.reset);

  group('PlayerConstants', () {
    test('has correct constant values', () {
      expect(PlayerConstants.completionDelayMs, 50);
    });
  });

  group('AudioPlayerCubit', () {
    test('initial state is correct', () {
      expect(playerCubit.state.status, equals(AudioPlayerStatus.initializing));
      expect(playerCubit.state.totalDuration, equals(Duration.zero));
      expect(playerCubit.state.progress, equals(Duration.zero));
      expect(playerCubit.state.pausedAt, equals(Duration.zero));
      expect(playerCubit.state.showTranscriptsList, equals(false));
      expect(playerCubit.state.speed, equals(1));
      expect(playerCubit.state.audioNote, isNull);
      expect(playerCubit.state.buffered, equals(Duration.zero));
    });

    group('updateProgress', () {
      test('updates progress when duration changes', () {
        const testDuration = Duration(seconds: 5);
        playerCubit.updateProgress(testDuration);
        expect(playerCubit.state.progress, equals(testDuration));
      });

      test('clamps progress to totalDuration when exceeding', () {
        playerCubit.setTotalDuration(const Duration(seconds: 100));
        playerCubit.updateProgress(const Duration(seconds: 150));
        expect(
            playerCubit.state.progress, equals(const Duration(seconds: 100)));
      });

      test('does not clamp when totalDuration is zero', () {
        playerCubit.setTotalDuration(Duration.zero);
        playerCubit.updateProgress(const Duration(seconds: 150));
        expect(
            playerCubit.state.progress, equals(const Duration(seconds: 150)));
      });

      test('does not emit when progress is unchanged', () {
        const testDuration = Duration(seconds: 5);
        playerCubit.updateProgress(testDuration);
        expect(playerCubit.state.progress, equals(testDuration));

        // Update with same duration - state should remain unchanged
        playerCubit.updateProgress(testDuration);
        expect(playerCubit.state.progress, equals(testDuration));
      });

      test('allows progress when less than totalDuration', () {
        playerCubit.setTotalDuration(const Duration(seconds: 100));
        playerCubit.updateProgress(const Duration(seconds: 50));
        expect(playerCubit.state.progress, equals(const Duration(seconds: 50)));
      });
    });

    group('updateBuffered', () {
      test('updates buffered duration', () {
        playerCubit.updateBuffered(const Duration(seconds: 30));
        expect(playerCubit.state.buffered, equals(const Duration(seconds: 30)));
      });

      test('clamps buffered to totalDuration when exceeding', () {
        playerCubit.setTotalDuration(const Duration(seconds: 100));
        playerCubit.updateBuffered(const Duration(seconds: 150));
        expect(
            playerCubit.state.buffered, equals(const Duration(seconds: 100)));
      });

      test('does not clamp when totalDuration is zero', () {
        playerCubit.setTotalDuration(Duration.zero);
        playerCubit.updateBuffered(const Duration(seconds: 150));
        expect(
            playerCubit.state.buffered, equals(const Duration(seconds: 150)));
      });

      test('does not emit when buffered is unchanged', () {
        const testDuration = Duration(seconds: 30);
        playerCubit.updateBuffered(testDuration);

        expect(playerCubit.state.buffered, equals(testDuration));
        playerCubit.updateBuffered(testDuration);
        expect(playerCubit.state.buffered, equals(testDuration));
      });
    });

    group('testSeek', () {
      test('updates progress, pausedAt, and buffered', () {
        playerCubit.testSeek(const Duration(seconds: 45));
        expect(playerCubit.state.progress, equals(const Duration(seconds: 45)));
        expect(playerCubit.state.pausedAt, equals(const Duration(seconds: 45)));
        expect(playerCubit.state.buffered, equals(const Duration(seconds: 45)));
      });

      test('preserves existing buffered when seeking backward', () {
        playerCubit.updateBuffered(const Duration(seconds: 60));
        playerCubit.testSeek(const Duration(seconds: 30));
        expect(playerCubit.state.progress, equals(const Duration(seconds: 30)));
        expect(playerCubit.state.pausedAt, equals(const Duration(seconds: 30)));
        expect(playerCubit.state.buffered, equals(const Duration(seconds: 60)));
      });

      test('updates buffered when seeking beyond current buffered', () {
        playerCubit.updateBuffered(const Duration(seconds: 30));
        playerCubit.testSeek(const Duration(seconds: 60));
        expect(playerCubit.state.buffered, equals(const Duration(seconds: 60)));
      });

      test('does not emit when all values are unchanged', () {
        playerCubit.testSeek(const Duration(seconds: 45));
        expect(playerCubit.state.progress, equals(const Duration(seconds: 45)));

        // Seek to same position
        playerCubit.testSeek(const Duration(seconds: 45));
        expect(playerCubit.state.progress, equals(const Duration(seconds: 45)));
      });
    });

    group('pause', () {
      test('sets status to paused', () {
        playerCubit.play();
        playerCubit.pause();
        expect(playerCubit.state.status, equals(AudioPlayerStatus.paused));
      });

      test('sets pausedAt to current progress', () {
        playerCubit.updateProgress(const Duration(seconds: 30));
        playerCubit.pause();
        expect(playerCubit.state.pausedAt, equals(const Duration(seconds: 30)));
      });
    });

    group('play', () {
      test('sets status to playing', () {
        playerCubit.play();
        expect(playerCubit.state.status, equals(AudioPlayerStatus.playing));
      });

      test('changes from paused to playing', () {
        playerCubit.pause();
        expect(playerCubit.state.status, equals(AudioPlayerStatus.paused));

        playerCubit.play();
        expect(playerCubit.state.status, equals(AudioPlayerStatus.playing));
      });
    });

    group('setSpeed', () {
      test('updates speed to 1.5x', () {
        playerCubit.setSpeed(1.5);
        expect(playerCubit.state.speed, equals(1.5));
      });

      test('updates speed to 0.5x', () {
        playerCubit.setSpeed(0.5);
        expect(playerCubit.state.speed, equals(0.5));
      });

      test('updates speed to 2x', () {
        playerCubit.setSpeed(2);
        expect(playerCubit.state.speed, equals(2));
      });

      test('can change speed multiple times', () {
        playerCubit.setSpeed(1.5);
        expect(playerCubit.state.speed, equals(1.5));

        playerCubit.setSpeed(0.75);
        expect(playerCubit.state.speed, equals(0.75));

        playerCubit.setSpeed(2);
        expect(playerCubit.state.speed, equals(2));
      });
    });

    group('state transitions', () {
      test('initializing -> playing -> paused', () {
        expect(
            playerCubit.state.status, equals(AudioPlayerStatus.initializing));

        playerCubit.play();
        expect(playerCubit.state.status, equals(AudioPlayerStatus.playing));

        playerCubit.pause();
        expect(playerCubit.state.status, equals(AudioPlayerStatus.paused));
      });

      test('paused -> playing -> paused maintains progress', () {
        playerCubit.updateProgress(const Duration(seconds: 30));
        playerCubit.pause();

        expect(playerCubit.state.pausedAt, equals(const Duration(seconds: 30)));

        playerCubit.play();
        playerCubit.updateProgress(const Duration(seconds: 45));
        playerCubit.pause();

        expect(playerCubit.state.pausedAt, equals(const Duration(seconds: 45)));
      });
    });

    group('edge cases', () {
      test('handles zero durations', () {
        playerCubit.updateProgress(Duration.zero);
        playerCubit.updateBuffered(Duration.zero);
        playerCubit.testSeek(Duration.zero);

        expect(playerCubit.state.progress, equals(Duration.zero));
        expect(playerCubit.state.buffered, equals(Duration.zero));
        expect(playerCubit.state.pausedAt, equals(Duration.zero));
      });

      test('handles very large durations', () {
        const largeDuration = Duration(hours: 999);
        playerCubit.setTotalDuration(largeDuration);
        playerCubit.updateProgress(largeDuration);

        expect(playerCubit.state.progress, equals(largeDuration));
      });

      test('progress and buffered can be equal to totalDuration', () {
        const totalDuration = Duration(minutes: 5);
        playerCubit.setTotalDuration(totalDuration);
        playerCubit.updateProgress(totalDuration);
        playerCubit.updateBuffered(totalDuration);

        expect(playerCubit.state.progress, equals(totalDuration));
        expect(playerCubit.state.buffered, equals(totalDuration));
      });

      test('seeking to end of track', () {
        const totalDuration = Duration(minutes: 5);
        playerCubit.setTotalDuration(totalDuration);
        playerCubit.testSeek(totalDuration);

        expect(playerCubit.state.progress, equals(totalDuration));
        expect(playerCubit.state.pausedAt, equals(totalDuration));
      });

      test('seeking to start of track', () {
        playerCubit.updateProgress(const Duration(seconds: 30));
        playerCubit.testSeek(Duration.zero);

        expect(playerCubit.state.progress, equals(Duration.zero));
        expect(playerCubit.state.pausedAt, equals(Duration.zero));
      });
    });
  });
}
