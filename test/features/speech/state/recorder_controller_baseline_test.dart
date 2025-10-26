import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

class _MockLoggingService extends Mock implements LoggingService {}

class _MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class _MockAudioPlayerCubit extends Mock implements AudioPlayerCubit {}

class _MockJournalDb extends Mock implements JournalDb {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockLoggingService logging;
  late _MockAudioRecorderRepository recorderRepo;
  late _MockAudioPlayerCubit playerCubit;
  late _MockJournalDb journalDb;
  late ProviderContainer container;
  late StreamController<Amplitude> ampController;

  setUp(() {
    logging = _MockLoggingService();
    recorderRepo = _MockAudioRecorderRepository();
    playerCubit = _MockAudioPlayerCubit();
    journalDb = _MockJournalDb();
    ampController = StreamController<Amplitude>.broadcast();

    when(() => playerCubit.state).thenReturn(
      AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        totalDuration: Duration.zero,
        progress: Duration.zero,
        pausedAt: Duration.zero,
        speed: 1,
        showTranscriptsList: false,
      ),
    );

    // Recorder repo defaults
    when(() => recorderRepo.amplitudeStream)
        .thenAnswer((_) => ampController.stream);
    when(() => recorderRepo.hasPermission()).thenAnswer((_) async => true);
    when(() => recorderRepo.isPaused()).thenAnswer((_) async => false);
    when(() => recorderRepo.isRecording()).thenAnswer((_) async => false);
    when(() => recorderRepo.startRecording()).thenAnswer((_) async => AudioNote(
          createdAt: DateTime.now(),
          audioFile: 'a.m4a',
          audioDirectory: '/audio/2025-10-26/',
          duration: Duration.zero,
        ));
    when(() => recorderRepo.stopRecording()).thenAnswer((_) async {});

    // Journal flag default
    when(() => journalDb.getConfigFlag(normalizeAudioOnDesktopFlag))
        .thenAnswer((_) async => true);

    getIt
      ..registerSingleton<LoggingService>(logging)
      ..registerSingleton<AudioPlayerCubit>(playerCubit)
      ..registerSingleton<JournalDb>(journalDb);

    container = ProviderContainer(
      overrides: [
        audioRecorderRepositoryProvider.overrideWithValue(recorderRepo),
      ],
    );
  });

  setUpAll(() {
    // Register fallback values for mocktail's any() on enums used by LoggingService
    registerFallbackValue(InsightLevel.info);
    registerFallbackValue(InsightType.log);
  });

  tearDown(() async {
    await ampController.close();
    container.dispose();
    await getIt.reset();
  });

  test('baseline logging fires on macOS with flag when buffer has samples',
      () async {
    if (!Platform.isMacOS) {
      return; // skip on non-macOS hosts
    }

    // Arrange
    final controller = container.read(audioRecorderControllerProvider.notifier);

    // Start a recording to set up _audioNote
    await controller.record();

    // Feed amplitude samples
    for (final v in [-30, -28, -32, -26, -24]) {
      ampController.add(Amplitude(current: v.toDouble(), max: v.toDouble()));
    }

    // Act
    await controller.stop();

    // Assert
    verify(
      () => logging.captureEvent(
        any<dynamic>(),
        domain: 'audio_normalization',
        subDomain: 'baseline',
        level: any(named: 'level'),
        type: any(named: 'type'),
      ),
    ).called(1);
  });

  test('baseline logging does not fire when flag disabled', () async {
    if (!Platform.isMacOS) {
      return; // skip on non-macOS hosts
    }

    when(() => journalDb.getConfigFlag(normalizeAudioOnDesktopFlag))
        .thenAnswer((_) async => false);

    final controller = container.read(audioRecorderControllerProvider.notifier);
    await controller.record();
    ampController.add(Amplitude(current: -28, max: -28));

    await controller.stop();

    verifyNever(
      () => logging.captureEvent(
        any<dynamic>(),
        domain: 'audio_normalization',
        subDomain: 'baseline',
        level: any(named: 'level'),
        type: any(named: 'type'),
      ),
    );
  });
}
