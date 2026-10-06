import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/speech/services/speech_dictionary_service.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/repository/speech_dictionary_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late SpeechDictionaryService service;
  late MockSpeechDictionaryRepository mockDictionaryRepository;
  late MockJournalRepository mockJournalRepository;

  final testTask = Task(
    data: TaskData(
      title: 'Test Task',
      checklistIds: const [],
      status: TaskStatus.open(
        id: 'status',
        createdAt: DateTime(2025),
        utcOffset: 0,
      ),
      statusHistory: const [],
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
    ),
    meta: Metadata(
      id: 'task-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
      categoryId: 'category-1',
    ),
  );

  final testTaskNoCategory = Task(
    data: TaskData(
      title: 'Task Without Category',
      checklistIds: const [],
      status: TaskStatus.open(
        id: 'status',
        createdAt: DateTime(2025),
        utcOffset: 0,
      ),
      statusHistory: const [],
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
    ),
    meta: Metadata(
      id: 'task-2',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
  );

  final testAudio = JournalAudio(
    meta: Metadata(
      id: 'audio-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    data: AudioData(
      audioFile: 'test.m4a',
      audioDirectory: '/tmp',
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      duration: const Duration(seconds: 30),
    ),
  );

  final testImage = JournalImage(
    meta: Metadata(
      id: 'image-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    data: ImageData(
      imageId: 'image-1',
      imageFile: 'test.jpg',
      imageDirectory: '/tmp',
      capturedAt: DateTime(2025),
    ),
  );

  final testTextEntry = JournalEntry(
    meta: Metadata(
      id: 'entry-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
  );

  setUp(() {
    mockDictionaryRepository = MockSpeechDictionaryRepository();
    mockJournalRepository = MockJournalRepository();
    service = SpeechDictionaryService(
      dictionaryRepository: mockDictionaryRepository,
      journalRepository: mockJournalRepository,
    );
  });

  void stubEntry(
    JournalEntity? entry, {
    List<JournalEntity> linked = const [],
  }) {
    when(
      () => mockJournalRepository.getJournalEntityById(any()),
    ).thenAnswer((_) async => entry);
    when(
      () => mockJournalRepository.getLinkedToEntities(
        linkedTo: any(named: 'linkedTo'),
      ),
    ).thenAnswer((_) async => linked);
  }

  void stubAdd(SpeechDictionaryAddResult result) {
    when(
      () => mockDictionaryRepository.addTerm(
        any(),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => result);
  }

  String? addedCategory() =>
      verify(
            () => mockDictionaryRepository.addTerm(
              any(),
              categoryId: captureAny(named: 'categoryId'),
            ),
          ).captured.single
          as String?;

  group('addTermForEntry resolves the category the term is limited to', () {
    test("a task's own category", () async {
      stubEntry(testTask);
      stubAdd(SpeechDictionaryAddResult.added);

      final result = await service.addTermForEntry(
        entryId: 'task-1',
        term: 'Kirkjubæjarklaustur',
      );

      expect(result, SpeechDictionaryResult.success);
      expect(addedCategory(), 'category-1');
    });

    test("a recording's linked task, when the recording has none", () async {
      stubEntry(testAudio, linked: [testTask]);
      stubAdd(SpeechDictionaryAddResult.added);

      await service.addTermForEntry(entryId: 'audio-1', term: 'Kubernetes');

      expect(addedCategory(), 'category-1');
    });

    test("an image's linked task, when the image has none", () async {
      stubEntry(testImage, linked: [testTask]);
      stubAdd(SpeechDictionaryAddResult.added);

      await service.addTermForEntry(entryId: 'image-1', term: 'Kubernetes');

      expect(addedCategory(), 'category-1');
    });

    test("the recording's own category before its task's", () async {
      stubEntry(
        testAudio.copyWith(
          meta: testAudio.meta.copyWith(categoryId: 'own-category'),
        ),
        linked: [testTask],
      );
      stubAdd(SpeechDictionaryAddResult.added);

      await service.addTermForEntry(entryId: 'audio-1', term: 'Kubernetes');

      expect(addedCategory(), 'own-category');
      verifyNever(
        () => mockJournalRepository.getLinkedToEntities(
          linkedTo: any(named: 'linkedTo'),
        ),
      );
    });

    for (final (name, entry, linked) in [
      ('a task without a category', testTaskNoCategory, <JournalEntity>[]),
      ('a recording with no linked task', testAudio, <JournalEntity>[]),
      (
        'a recording whose task has no category',
        testAudio,
        <JournalEntity>[testTaskNoCategory],
      ),
      ('a text entry without a category', testTextEntry, <JournalEntity>[]),
    ]) {
      test('none for $name, so the term applies to all', () async {
        stubEntry(entry, linked: linked);
        stubAdd(SpeechDictionaryAddResult.added);

        final result = await service.addTermForEntry(
          entryId: entry.meta.id,
          term: 'Kubernetes',
        );

        expect(result, SpeechDictionaryResult.success);
        expect(addedCategory(), isNull);
      });
    }
  });

  group('addTermForEntry reports', () {
    for (final (added, expected) in [
      (SpeechDictionaryAddResult.added, SpeechDictionaryResult.success),
      (SpeechDictionaryAddResult.scopeExtended, SpeechDictionaryResult.success),
      (
        SpeechDictionaryAddResult.alreadyPresent,
        SpeechDictionaryResult.duplicate,
      ),
      (SpeechDictionaryAddResult.emptyTerm, SpeechDictionaryResult.emptyTerm),
      (
        SpeechDictionaryAddResult.termTooLong,
        SpeechDictionaryResult.termTooLong,
      ),
    ]) {
      test('$expected when the dictionary answers $added', () async {
        stubEntry(testTask);
        stubAdd(added);

        expect(
          await service.addTermForEntry(entryId: 'task-1', term: 'Kubernetes'),
          expected,
        );
      });
    }

    test('saveFailed when the write throws', () async {
      stubEntry(testTask);
      when(
        () => mockDictionaryRepository.addTerm(
          any(),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenThrow(Exception('disk full'));

      expect(
        await service.addTermForEntry(entryId: 'task-1', term: 'Kubernetes'),
        SpeechDictionaryResult.saveFailed,
      );
    });

    test('entryNotFound for an unknown entry, without writing', () async {
      stubEntry(null);

      expect(
        await service.addTermForEntry(entryId: 'missing', term: 'Kubernetes'),
        SpeechDictionaryResult.entryNotFound,
      );
      verifyZeroInteractions(mockDictionaryRepository);
    });

    for (final (name, term, expected) in [
      ('an empty term', '', SpeechDictionaryResult.emptyTerm),
      ('a whitespace-only term', '   ', SpeechDictionaryResult.emptyTerm),
      (
        'a term over the length limit',
        'a' * (kMaxTermLength + 1),
        SpeechDictionaryResult.termTooLong,
      ),
    ]) {
      test('$expected for $name, before reading anything', () async {
        expect(
          await service.addTermForEntry(entryId: 'task-1', term: term),
          expected,
        );
        verifyZeroInteractions(mockJournalRepository);
        verifyZeroInteractions(mockDictionaryRepository);
      });
    }

    test('trims the term before adding it', () async {
      stubEntry(testTask);
      stubAdd(SpeechDictionaryAddResult.added);

      await service.addTermForEntry(entryId: 'task-1', term: '  Kubernetes  ');

      verify(
        () => mockDictionaryRepository.addTerm(
          'Kubernetes',
          categoryId: 'category-1',
        ),
      ).called(1);
    });
  });
}
