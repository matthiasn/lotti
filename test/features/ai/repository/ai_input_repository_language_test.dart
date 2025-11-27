import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockRef extends Mock implements Ref {}

class MockTaskProgressRepository extends Mock
    implements TaskProgressRepository {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

void main() {
  late AiInputRepository repository;
  late MockJournalDb mockDb;
  late MockRef mockRef;
  late MockTaskProgressRepository mockTaskProgressRepo;
  late MockPersistenceLogic mockPersistenceLogic;

  setUp(() {
    mockDb = MockJournalDb();
    mockRef = MockRef();
    mockTaskProgressRepo = MockTaskProgressRepository();
    mockPersistenceLogic = MockPersistenceLogic();

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

    when(() => mockRef.read(taskProgressRepositoryProvider))
        .thenReturn(mockTaskProgressRepo);

    repository = AiInputRepository(mockRef);
  });

  tearDown(() {
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
  });

  Metadata createMetadata({String id = 'test-id'}) {
    return Metadata(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      dateFrom: DateTime.now(),
      dateTo: DateTime.now(),
    );
  }

  void setupTaskProgressMock() {
    when(() => mockTaskProgressRepo.getTaskProgress(
          durations: any(named: 'durations'),
          estimate: any(named: 'estimate'),
        )).thenReturn(
      const TaskProgressState(
        progress: Duration.zero,
        estimate: Duration.zero,
      ),
    );
  }

  group('Language support in task data', () {
    test('includes languageCode in generated task object', () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          languageCode: 'de',
        ),
      );

      when(() => mockDb.journalEntityById('test-id'))
          .thenAnswer((_) async => task);
      when(() => mockTaskProgressRepo.getTaskProgressData(id: 'test-id'))
          .thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(() => mockDb.getLinkedEntities('test-id'))
          .thenAnswer((_) async => []);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.languageCode, equals('de'));
    });

    test('handles null languageCode', () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      when(() => mockDb.journalEntityById('test-id'))
          .thenAnswer((_) async => task);
      when(() => mockTaskProgressRepo.getTaskProgressData(id: 'test-id'))
          .thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(() => mockDb.getLinkedEntities('test-id'))
          .thenAnswer((_) async => []);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.languageCode, isNull);
    });

    test('includes transcript language in log entries when no edited text',
        () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      // Audio entry WITHOUT edited text - should use original transcript
      final audioEntry = JournalAudio(
        meta: createMetadata(id: 'audio-1'),
        data: AudioData(
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          audioFile: 'test.mp3',
          audioDirectory: '/audio',
          duration: const Duration(minutes: 5),
          transcripts: [
            AudioTranscript(
              created: DateTime.now(),
              library: 'whisper',
              model: 'base',
              detectedLanguage: 'es',
              transcript: 'Este es un texto en español',
            ),
          ],
        ),
        // No entryText - so audioTranscript should be included
      );

      when(() => mockDb.journalEntityById('test-id'))
          .thenAnswer((_) async => task);
      when(() => mockTaskProgressRepo.getTaskProgressData(id: 'test-id'))
          .thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(() => mockDb.getLinkedEntities('test-id'))
          .thenAnswer((_) async => [audioEntry]);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.logEntries, hasLength(1));

      final logEntry = result.logEntries.first;
      expect(logEntry.entryType, equals('audio'));
      expect(logEntry.audioTranscript, equals('Este es un texto en español'));
      expect(logEntry.transcriptLanguage, equals('es'));
      expect(logEntry.text, isEmpty);
    });

    test('uses edited text instead of original transcript when available',
        () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      // Audio entry WITH edited text - should use edited text, not transcript
      final audioEntry = JournalAudio(
        meta: createMetadata(id: 'audio-1'),
        data: AudioData(
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          audioFile: 'test.mp3',
          audioDirectory: '/audio',
          duration: const Duration(minutes: 5),
          transcripts: [
            AudioTranscript(
              created: DateTime.now(),
              library: 'whisper',
              model: 'base',
              detectedLanguage: 'es',
              transcript: 'Original transcript with errors',
            ),
          ],
        ),
        entryText: const EntryText(
          plainText: 'Corrected transcript by user',
        ),
      );

      when(() => mockDb.journalEntityById('test-id'))
          .thenAnswer((_) async => task);
      when(() => mockTaskProgressRepo.getTaskProgressData(id: 'test-id'))
          .thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(() => mockDb.getLinkedEntities('test-id'))
          .thenAnswer((_) async => [audioEntry]);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.logEntries, hasLength(1));

      final logEntry = result.logEntries.first;
      expect(logEntry.entryType, equals('audio'));
      // Edited text takes precedence - audioTranscript should be null
      expect(logEntry.audioTranscript, isNull);
      expect(logEntry.transcriptLanguage, isNull);
      expect(logEntry.text, equals('Corrected transcript by user'));
    });

    test('handles multiple audio transcripts', () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      final audioEntry = JournalAudio(
        meta: createMetadata(id: 'audio-1'),
        data: AudioData(
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          audioFile: 'test.mp3',
          audioDirectory: '/audio',
          duration: const Duration(minutes: 5),
          transcripts: [
            AudioTranscript(
              created: DateTime.now().subtract(const Duration(hours: 1)),
              library: 'whisper',
              model: 'base',
              detectedLanguage: 'en',
              transcript: 'Old English transcript',
            ),
            AudioTranscript(
              created: DateTime.now(),
              library: 'whisper',
              model: 'base',
              detectedLanguage: 'de',
              transcript: 'Dies ist die neueste deutsche Transkription',
            ),
          ],
        ),
      );

      when(() => mockDb.journalEntityById('test-id'))
          .thenAnswer((_) async => task);
      when(() => mockTaskProgressRepo.getTaskProgressData(id: 'test-id'))
          .thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(() => mockDb.getLinkedEntities('test-id'))
          .thenAnswer((_) async => [audioEntry]);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.logEntries, hasLength(1));

      final logEntry = result.logEntries.first;
      // Should use the most recent transcript
      expect(logEntry.audioTranscript,
          equals('Dies ist die neueste deutsche Transkription'));
      expect(logEntry.transcriptLanguage, equals('de'));
    });

    test('sets correct entry types for different journal entities', () async {
      final task = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      final textEntry = JournalEntry(
        meta: createMetadata(id: 'text-1'),
        entryText: const EntryText(plainText: 'Some text'),
      );

      final imageEntry = JournalImage(
        meta: createMetadata(id: 'image-1'),
        data: ImageData(
          capturedAt: DateTime.now(),
          imageId: 'img-1',
          imageFile: 'test.jpg',
          imageDirectory: '/images',
        ),
      );

      final audioEntry = JournalAudio(
        meta: createMetadata(id: 'audio-1'),
        data: AudioData(
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          audioFile: 'test.mp3',
          audioDirectory: '/audio',
          duration: const Duration(minutes: 5),
        ),
      );

      when(() => mockDb.journalEntityById('test-id'))
          .thenAnswer((_) async => task);
      when(() => mockTaskProgressRepo.getTaskProgressData(id: 'test-id'))
          .thenAnswer((_) async => null);
      setupTaskProgressMock();
      when(() => mockDb.getLinkedEntities('test-id'))
          .thenAnswer((_) async => [textEntry, imageEntry, audioEntry]);

      final result = await repository.generate('test-id');

      expect(result, isNotNull);
      expect(result!.logEntries, hasLength(3));

      expect(result.logEntries[0].entryType, equals('text'));
      expect(result.logEntries[1].entryType, equals('image'));
      expect(result.logEntries[2].entryType, equals('audio'));
    });
  });
}
