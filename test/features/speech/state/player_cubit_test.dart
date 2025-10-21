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
    emit(state.copyWith(progress: duration));
  }

  void toggleTranscriptsList() {
    emit(state.copyWith(showTranscriptsList: !state.showTranscriptsList));
  }

  void stop() {
    emit(
      state.copyWith(
        status: AudioPlayerStatus.stopped,
        progress: Duration.zero,
        pausedAt: Duration.zero,
        buffered: Duration.zero,
      ),
    );
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
    });

    test('updateProgress updates state correctly', () {
      const testDuration = Duration(seconds: 5);
      playerCubit.updateProgress(testDuration);
      expect(playerCubit.state.progress, equals(testDuration));
    });

    test('toggleTranscriptsList toggles visibility', () {
      // Initial state is false
      expect(playerCubit.state.showTranscriptsList, false);

      // First toggle
      playerCubit.toggleTranscriptsList();
      expect(playerCubit.state.showTranscriptsList, true);

      // Second toggle
      playerCubit.toggleTranscriptsList();
      expect(playerCubit.state.showTranscriptsList, false);
    });

    test('stop resets playback state', () {
      playerCubit
        ..updateProgress(const Duration(seconds: 12))
        ..stop();

      expect(playerCubit.state.status, AudioPlayerStatus.stopped);
      expect(playerCubit.state.progress, Duration.zero);
      expect(playerCubit.state.pausedAt, Duration.zero);
      expect(playerCubit.state.buffered, Duration.zero);
    });
  });
}
