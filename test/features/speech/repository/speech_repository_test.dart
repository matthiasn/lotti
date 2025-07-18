import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

// Fakes
class FakeJournalAudio extends Fake implements JournalAudio {}

class FakeMetadata extends Fake implements Metadata {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    // Register fakes for any() matchers if needed for complex objects
    registerFallbackValue(FakeJournalAudio());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(DateTime.now()); // For date matching
  });

  setUp(() {
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockLoggingService();

    // Unregister specific services before re-registering for the test
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }

    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }

    // Register mocks with getIt
    getIt.registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    // ignore_for_file: cascade_invocations
    getIt.registerSingleton<JournalDb>(mockJournalDb);
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Default stub for logging to avoid errors in tests not focused on logging
    when(
      () => mockLoggingService.captureException(
        // ignore_for_file: inference_failure_on_function_invocation
        any(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
  });

  group('SpeechRepository', () {
    group('createAudioEntry', () {
      final testAudioNote = AudioNote(
        audioDirectory: '/test/dir',
        audioFile: 'test.aac',
        duration: const Duration(seconds: 30),
        createdAt: DateTime(2023, 1, 1, 10),
      );
      const testLanguage = 'en-US';
      const testLinkedId = 'linked_entry_123';
      const testCategoryId = 'category_abc';
      final expectedAudioData = AudioData(
        audioDirectory: testAudioNote.audioDirectory,
        duration: testAudioNote.duration,
        audioFile: testAudioNote.audioFile,
        dateTo: testAudioNote.createdAt.add(testAudioNote.duration),
        dateFrom: testAudioNote.createdAt,
        language: testLanguage,
      );
      final testMetadata = Metadata(
        id: 'new_audio_id',
        createdAt: DateTime(2023, 1, 1, 10),
        updatedAt: DateTime(2023, 1, 1, 10),
        dateFrom: expectedAudioData.dateFrom,
        dateTo: expectedAudioData.dateTo,
        flag: EntryFlag.import,
      );

      test('successfully creates audio entry', () async {
        // Arrange
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: expectedAudioData.dateFrom,
            dateTo: expectedAudioData.dateTo,
            uuidV5Input: json.encode(
              expectedAudioData.copyWith(
                autoTranscribeWasActive: false,
                language: testLanguage,
              ),
            ),
            flag: EntryFlag.import,
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalAudio>()),
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await SpeechRepository.createAudioEntry(
          testAudioNote,
          language: testLanguage,
        );

        // Assert
        expect(result, isA<JournalAudio>());
        expect(result?.data.autoTranscribeWasActive, isFalse);
      });

      test('successfully creates audio entry with linkedId and categoryId',
          () async {
        // Arrange
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: expectedAudioData.dateFrom,
            dateTo: expectedAudioData.dateTo,
            uuidV5Input: json.encode(
              expectedAudioData.copyWith(
                autoTranscribeWasActive: false,
                language: testLanguage,
              ),
            ),
            flag: EntryFlag.import,
            categoryId: testCategoryId,
          ),
        ).thenAnswer(
          (_) async => testMetadata.copyWith(categoryId: testCategoryId),
        );
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalAudio>()),
            linkedId: testLinkedId,
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await SpeechRepository.createAudioEntry(
          testAudioNote,
          language: testLanguage,
          linkedId: testLinkedId,
          categoryId: testCategoryId,
        );

        // Assert
        expect(result, isA<JournalAudio>());
        expect(result?.meta.categoryId, testCategoryId);

        final capturedEntity = verify(
          () => mockPersistenceLogic.createDbEntity(
            captureAny(that: isA<JournalAudio>()),
            linkedId: testLinkedId,
          ),
        ).captured.single as JournalAudio;
        expect(capturedEntity.meta.categoryId, testCategoryId);

        verify(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: expectedAudioData.dateFrom,
            dateTo: expectedAudioData.dateTo,
            uuidV5Input: json.encode(
              expectedAudioData.copyWith(
                autoTranscribeWasActive: false,
                language: testLanguage,
              ),
            ),
            flag: EntryFlag.import,
            categoryId: testCategoryId,
          ),
        ).called(1);
      });

      test('returns null and logs exception when createMetadata throws',
          () async {
        // Arrange
        final exception = Exception('Metadata creation error');
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            uuidV5Input: any(named: 'uuidV5Input'),
            flag: any(named: 'flag'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenThrow(exception);

        // Act
        final result = await SpeechRepository.createAudioEntry(
          testAudioNote,
          language: testLanguage,
        );

        // Assert
        expect(result, isNull);
        verify(
          () => mockLoggingService.captureException(
            exception,
            domain: 'persistence_logic',
            subDomain: 'createAudioEntry',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
        verifyNever(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
          ),
        );
      });

      test('returns null and logs exception when createDbEntity throws',
          () async {
        // Arrange
        final exception = Exception('DB entity creation error');
        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: expectedAudioData.dateFrom,
            dateTo: expectedAudioData.dateTo,
            uuidV5Input: json.encode(
              expectedAudioData.copyWith(
                autoTranscribeWasActive: false,
                language: testLanguage,
              ),
            ),
            flag: EntryFlag.import,
          ),
        ).thenAnswer((_) async => testMetadata);
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(that: isA<JournalAudio>()),
          ),
        ).thenThrow(exception);

        // Act
        final result = await SpeechRepository.createAudioEntry(
          testAudioNote,
          language: testLanguage,
        );

        // Assert
        expect(result, isNull);
        verify(
          () => mockLoggingService.captureException(
            exception,
            domain: 'persistence_logic',
            subDomain: 'createAudioEntry',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('updateLanguage', () {
      const testEntryId = 'audio_entry_123';
      const newLanguage = 'es-ES';
      final initialAudioData = AudioData(
        audioDirectory: '/test/dir',
        audioFile: 'test.aac',
        duration: const Duration(seconds: 30),
        dateFrom: DateTime(2023, 1, 1, 10),
        dateTo: DateTime(2023, 1, 1, 10, 0, 30),
        language: 'en-US',
      );
      final initialMetadata = Metadata(
        id: testEntryId,
        createdAt: DateTime(2023, 1, 1, 9),
        updatedAt: DateTime(2023, 1, 1, 9, 30),
        dateFrom: initialAudioData.dateFrom,
        dateTo: initialAudioData.dateTo,
      );
      final testJournalAudioEntry = JournalAudio(
        meta: initialMetadata,
        data: initialAudioData,
      );

      test('successfully updates language for a JournalAudio entry', () async {
        // Arrange
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => testJournalAudioEntry);
        when(() => mockPersistenceLogic.updateMetadata(initialMetadata))
            .thenAnswer(
          (_) async => initialMetadata.copyWith(
            updatedAt: DateTime.now(),
          ),
        ); // Simulate updatedAt change
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(that: isA<JournalAudio>()),
          ),
        ).thenAnswer((_) async => true);

        // Act
        await SpeechRepository.updateLanguage(
          journalEntityId: testEntryId,
          language: newLanguage,
        );

        // Assert
        verify(() => mockJournalDb.journalEntityById(testEntryId)).called(1);
        verify(() => mockPersistenceLogic.updateMetadata(initialMetadata))
            .called(1);
        final captured = verify(
          () => mockPersistenceLogic
              .updateDbEntity(captureAny(that: isA<JournalAudio>())),
        ).captured;
        expect(captured.length, 1);
        final updatedEntry = captured.first as JournalAudio;
        expect(updatedEntry.data.language, newLanguage);
        expect(updatedEntry.meta.id, testEntryId);
      });

      test('does nothing and logs if entry is not JournalAudio', () async {
        // Arrange
        final notAudioEntry = JournalEntry(
          meta: initialMetadata,
          entryText: const EntryText(plainText: 'text'),
        );
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => notAudioEntry);

        // Act
        await SpeechRepository.updateLanguage(
          journalEntityId: testEntryId,
          language: newLanguage,
        );

        // Assert
        verify(() => mockJournalDb.journalEntityById(testEntryId)).called(1);
        verify(
          () => mockLoggingService.captureException(
            'not an audio entry',
            domain: 'persistence_logic',
            subDomain: 'updateLanguage',
            // stackTrace is optional here as it might not be generated for simple string exceptions
          ),
        ).called(1);
        verifyNever(() => mockPersistenceLogic.updateMetadata(any()));
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('does nothing if journal entity is not found', () async {
        // Arrange
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => null);

        // Act
        await SpeechRepository.updateLanguage(
          journalEntityId: testEntryId,
          language: newLanguage,
        );

        // Assert
        verify(() => mockJournalDb.journalEntityById(testEntryId)).called(1);
        verifyNever(
          () => mockLoggingService.captureException(
            any(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any(named: 'stackTrace'),
          ),
        );
        verifyNever(() => mockPersistenceLogic.updateMetadata(any()));
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('logs exception if journalEntityById throws', () async {
        // Arrange
        final exception = Exception('DB fetch error');
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenThrow(exception);

        // Act
        await SpeechRepository.updateLanguage(
          journalEntityId: testEntryId,
          language: newLanguage,
        );

        // Assert
        verify(() => mockJournalDb.journalEntityById(testEntryId)).called(1);
        verify(
          () => mockLoggingService.captureException(
            exception,
            domain: 'persistence_logic',
            subDomain: 'updateLanguage',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
        verifyNever(() => mockPersistenceLogic.updateMetadata(any()));
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('logs exception if updateMetadata throws', () async {
        // Arrange
        final exception = Exception('Metadata update error');
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => testJournalAudioEntry);
        when(() => mockPersistenceLogic.updateMetadata(initialMetadata))
            .thenThrow(exception);

        // Act
        await SpeechRepository.updateLanguage(
          journalEntityId: testEntryId,
          language: newLanguage,
        );

        // Assert
        verify(
          () => mockLoggingService.captureException(
            exception,
            domain: 'persistence_logic',
            subDomain: 'updateLanguage',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('logs exception if updateDbEntity throws', () async {
        // Arrange
        final exception = Exception('DB entity update error');
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => testJournalAudioEntry);
        when(() => mockPersistenceLogic.updateMetadata(initialMetadata))
            .thenAnswer(
          (_) async => initialMetadata.copyWith(updatedAt: DateTime.now()),
        );
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(that: isA<JournalAudio>()),
          ),
        ).thenThrow(exception);

        // Act
        await SpeechRepository.updateLanguage(
          journalEntityId: testEntryId,
          language: newLanguage,
        );

        // Assert
        verify(
          () => mockLoggingService.captureException(
            exception,
            domain: 'persistence_logic',
            subDomain: 'updateLanguage',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('removeAudioTranscript', () {
      const testEntryId = 'audio_entry_remove_transcript_123';
      final transcript1 = AudioTranscript(
        created: DateTime(2023, 1, 3, 10),
        library: 'lib1',
        model: 'mod1',
        detectedLanguage: 'en',
        transcript: 'Transcript 1',
      );
      final transcript2 = AudioTranscript(
        created: DateTime(2023, 1, 3, 11),
        library: 'lib2',
        model: 'mod2',
        detectedLanguage: 'es',
        transcript: 'Transcript 2',
      );
      final transcriptToRemove = transcript1; // The one we intend to remove
      final transcriptToKeep = transcript2; // The one that should remain
      final nonExistingTranscript = AudioTranscript(
        created: DateTime(2023, 1, 3, 12), // Different created time
        library: 'lib_other', model: 'mod_other', detectedLanguage: 'fr',
        transcript: 'Non-existing',
      );

      final initialAudioDataWithTwoTranscripts = AudioData(
        audioDirectory: '/test/dir',
        audioFile: 'test_remove.aac',
        duration: const Duration(seconds: 120),
        dateFrom: DateTime(2023, 1, 3, 9),
        dateTo: DateTime(2023, 1, 3, 9, 2),
        language: 'en-US',
        transcripts: [transcriptToRemove, transcriptToKeep],
      );
      final initialMetadata = Metadata(
        id: testEntryId,
        createdAt: DateTime(2023, 1, 3, 8),
        updatedAt: DateTime(2023, 1, 3, 8, 30),
        dateFrom: initialAudioDataWithTwoTranscripts.dateFrom,
        dateTo: initialAudioDataWithTwoTranscripts.dateTo,
      );
      final testJournalAudioEntryWithTranscripts = JournalAudio(
        meta: initialMetadata,
        data: initialAudioDataWithTwoTranscripts,
        entryText: const EntryText(plainText: 'Some audio text'),
      );

      setUp(() {
        // Common stubs for this group
        when(() => mockPersistenceLogic.updateMetadata(any<Metadata>()))
            .thenAnswer((invocation) async {
          final originalMeta = invocation.positionalArguments[0] as Metadata;
          return originalMeta.copyWith(updatedAt: DateTime.now());
        });
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(that: isA<JournalAudio>()),
          ),
        ).thenAnswer((_) async => true);
      });

      test('successfully removes an existing transcript', () async {
        // Arrange
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => testJournalAudioEntryWithTranscripts);

        // Act
        final result = await SpeechRepository.removeAudioTranscript(
          journalEntityId: testEntryId,
          transcript: transcriptToRemove,
        );

        // Assert
        expect(result, isTrue);
        final captured = verify(
          () => mockPersistenceLogic
              .updateDbEntity(captureAny(that: isA<JournalAudio>())),
        ).captured;
        expect(captured.length, 1);
        final updatedEntry = captured.first as JournalAudio;
        expect(updatedEntry.data.transcripts, isNotNull);
        expect(
          updatedEntry.data.transcripts,
          isNot(contains(transcriptToRemove)),
        );
        expect(updatedEntry.data.transcripts, contains(transcriptToKeep));
        expect(updatedEntry.data.transcripts?.length, 1);
      });

      test(
          'does nothing if transcript to remove does not exist (based on created time)',
          () async {
        // Arrange
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => testJournalAudioEntryWithTranscripts);

        // Act
        final result = await SpeechRepository.removeAudioTranscript(
          journalEntityId: testEntryId,
          transcript: nonExistingTranscript,
        );

        // Assert
        expect(result, isTrue);
        final captured = verify(
          () => mockPersistenceLogic
              .updateDbEntity(captureAny(that: isA<JournalAudio>())),
        ).captured;
        expect(captured.length, 1);
        final updatedEntry = captured.first as JournalAudio;
        expect(
          updatedEntry.data.transcripts?.length,
          2,
        ); // Should remain unchanged
        expect(updatedEntry.data.transcripts, contains(transcriptToRemove));
        expect(updatedEntry.data.transcripts, contains(transcriptToKeep));
      });

      test('returns false if journal entity is not found', () async {
        // Arrange
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => null);

        // Act
        final result = await SpeechRepository.removeAudioTranscript(
          journalEntityId: testEntryId,
          transcript: transcriptToRemove,
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('does nothing and logs if entry is not JournalAudio', () async {
        // Arrange
        final notAudioEntry = JournalEntry(
          meta: initialMetadata,
          entryText: const EntryText(plainText: 'text'),
        );
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => notAudioEntry);

        // Act
        final result = await SpeechRepository.removeAudioTranscript(
          journalEntityId: testEntryId,
          transcript: transcriptToRemove,
        );

        // Assert
        expect(
          result,
          isTrue,
        ); // Original method returns true even in orElse/catch
        verify(
          () => mockLoggingService.captureException(
            'not an audio entry',
            domain: 'persistence_logic',
            subDomain: 'removeAudioTranscript',
          ),
        ).called(1);
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('logs exception if journalEntityById throws', () async {
        // Arrange
        final exception = Exception('DB fetch error for transcript removal');
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenThrow(exception);

        // Act
        final result = await SpeechRepository.removeAudioTranscript(
          journalEntityId: testEntryId,
          transcript: transcriptToRemove,
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockLoggingService.captureException(
            exception,
            domain: 'persistence_logic',
            subDomain: 'removeAudioTranscript',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
        verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
      });

      test('logs exception if updateDbEntity throws', () async {
        // Arrange
        final exception =
            Exception('DB entity update error for transcript removal');
        when(() => mockJournalDb.journalEntityById(testEntryId))
            .thenAnswer((_) async => testJournalAudioEntryWithTranscripts);
        when(
          () => mockPersistenceLogic.updateDbEntity(
            any(that: isA<JournalAudio>()),
          ),
        ).thenThrow(exception);

        // Act
        final result = await SpeechRepository.removeAudioTranscript(
          journalEntityId: testEntryId,
          transcript: transcriptToRemove,
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockLoggingService.captureException(
            exception,
            domain: 'persistence_logic',
            subDomain: 'removeAudioTranscript',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });
  });
}
