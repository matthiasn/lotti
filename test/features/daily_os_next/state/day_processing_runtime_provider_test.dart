import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_spool_recovery_service.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_transcript_writer.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_processor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_runtime.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late Directory root;
  late DayProcessingOutboxRepository outbox;
  late MockJournalDb journalDb;
  late MockPersistenceLogic persistenceLogic;
  late MockVectorClockService vectorClock;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('day-runtime-provider-test-');
    outbox = DayProcessingOutboxRepository(rootDirectory: root);
    persistenceLogic = MockPersistenceLogic();
    vectorClock = MockVectorClockService();
    when(vectorClock.getHost).thenAnswer((_) async => 'host-1');
    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(root)
          ..registerSingleton<PersistenceLogic>(persistenceLogic)
          ..registerSingleton<VectorClockService>(vectorClock)
          ..registerSingleton<DayProcessingOutboxRepository>(outbox);
      },
    );
    journalDb = mocks.journalDb;
    when(
      () => journalDb.getJournalEntities(
        types: const ['JournalAudio'],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: const [1, 0],
        ids: null,
        limit: 64,
      ),
    ).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    await outbox.dispose();
    await tearDownTestGetIt();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('constructs every local-first runtime dependency', () async {
    final transcriber = MockAudioTranscriptionService();
    final container = ProviderContainer(
      overrides: [
        audioTranscriptionServiceProvider.overrideWithValue(transcriber),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(dayProcessingOutboxRepositoryProvider),
      same(outbox),
    );
    final writer = container.read(dayAudioTranscriptWriterProvider);
    expect(writer, isA<DayAudioTranscriptWriter>());
    expect(writer.journalDb, same(journalDb));
    expect(writer.persistenceLogic, same(persistenceLogic));

    final recovery = container.read(dayAudioSpoolRecoveryServiceProvider);
    expect(recovery, isA<DayAudioSpoolRecoveryService>());
    expect(recovery.journalDb, same(journalDb));
    expect(recovery.outbox, same(outbox));
    expect(recovery.assetRoot, same(root));

    expect(
      container.read(dayProcessingOutboxProcessorProvider),
      isA<DayProcessingOutboxProcessor>(),
    );
    final runtime = container.read(dayProcessingRuntimeProvider);
    expect(runtime, isA<DayProcessingRuntime>());
    await runtime.nudge();
    verify(vectorClock.getHost).called(1);
  });
}
