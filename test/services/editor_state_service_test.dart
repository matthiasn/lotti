import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorStateService Tests', () {
    late MockJournalDb mockJournalDb;
    late MockEditorDb mockEditorDb;
    late EditorStateService editorStateService;

    setUpAll(() {
      registerFallbackValue(testEpochDateTime);
      registerFallbackValue(FakeQuillController());
    });

    setUp(() {
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      if (getIt.isRegistered<EditorDb>()) {
        getIt.unregister<EditorDb>();
      }

      mockJournalDb = MockJournalDb();
      mockEditorDb = MockEditorDb();

      when(() => mockEditorDb.allDrafts()).thenAnswer(
        (_) => FakeDraftsQuery(),
      );

      when(() => mockEditorDb.insertDraftState(
            entryId: any(named: 'entryId'),
            lastSaved: any(named: 'lastSaved'),
            draftDeltaJson: any(named: 'draftDeltaJson'),
          )).thenAnswer((_) async => 1);

      when(() => mockEditorDb.setDraftSaved(
            entryId: any(named: 'entryId'),
            lastSaved: any(named: 'lastSaved'),
          )).thenAnswer((_) async => 1);

      // Mock entityById to return null by default
      when(() => mockJournalDb.entityById(any())).thenAnswer((_) async => null);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EditorDb>(mockEditorDb);

      editorStateService = EditorStateService();
    });

    test('init populates editorStateById with matching drafts', () async {
      final testTime = DateTime.now();
      final testEntity = FakeJournalDbEntity(updatedAt: testTime);

      final draftEntry = EditorDraftState(
        id: 'draft-id',
        entryId: 'test-entry-id',
        status: 'DRAFT',
        createdAt: testEpochDateTime,
        delta: '{"ops":[{"insert":"test"}]}',
        lastSaved: testTime,
      );

      when(() => mockEditorDb.allDrafts()).thenAnswer(
        (_) => FakeDraftsQueryWithData([draftEntry]),
      );

      when(() => mockJournalDb.entityById('test-entry-id'))
          .thenAnswer((_) async => testEntity);

      final service = EditorStateService();
      await service.init();

      expect(service.editorStateById['test-entry-id'], isNotNull);
      expect(service.editorStateById['test-entry-id'],
          '{"ops":[{"insert":"test"}]}');
    });

    test('init skips drafts when updatedAt does not match', () async {
      final testEntity = FakeJournalDbEntity(updatedAt: DateTime(2025));

      final draftEntry = EditorDraftState(
        id: 'draft-id',
        entryId: 'test-entry-id',
        status: 'DRAFT',
        createdAt: testEpochDateTime,
        delta: '{"ops":[{"insert":"test"}]}',
        lastSaved: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      when(() => mockEditorDb.allDrafts()).thenAnswer(
        (_) => FakeDraftsQueryWithData([draftEntry]),
      );

      when(() => mockJournalDb.entityById('test-entry-id'))
          .thenAnswer((_) async => testEntity);

      final service = EditorStateService();
      await service.init();

      expect(service.editorStateById['test-entry-id'], isNull);
    });

    test('getDelta returns stored delta', () async {
      editorStateService.editorStateById['test-id'] =
          '{"ops":[{"insert":"test"}]}';

      final result = editorStateService.getDelta('test-id');
      expect(result, '{"ops":[{"insert":"test"}]}');
    });

    test('getDelta returns null for non-existing id', () {
      final result = editorStateService.getDelta('non-existing-id');
      expect(result, isNull);
    });

    test('saveTempState stores delta and removes selection', () {
      const entryId = 'test-entry-id';
      const deltaJson = '{"ops":[{"insert":"new content"}]}';

      editorStateService.saveTempState(
        id: entryId,
        lastSaved: testEpochDateTime,
        json: deltaJson,
      );

      expect(editorStateService.editorStateById[entryId], deltaJson);
    });

    test('saveTempState triggers unsaved stream', () {
      const entryId = 'test-entry-id';
      const deltaJson = '{"ops":[{"insert":"new content"}]}';

      when(() => mockEditorDb.getLatestDraft(any(),
          lastSaved: any(named: 'lastSaved'))).thenAnswer((_) async => null);

      final stream =
          editorStateService.getUnsavedStream(entryId, testEpochDateTime);

      // The stream should first emit `false` (no unsaved changes),
      // then `true` after saveTempState is called.
      expectLater(stream, emitsInOrder([false, true]));

      editorStateService.saveTempState(
        id: entryId,
        lastSaved: testEpochDateTime,
        json: deltaJson,
      );
    });

    test('entryWasSaved removes delta from cache', () async {
      const entryId = 'test-entry-id';

      editorStateService.editorStateById[entryId] =
          '{"ops":[{"insert":"test"}]}';

      final mockController = FakeQuillController(
        selection: const TextSelection.collapsed(offset: 0),
      );

      await editorStateService.entryWasSaved(
        id: entryId,
        lastSaved: testEpochDateTime,
        controller: mockController,
      );

      expect(editorStateService.editorStateById[entryId], isNull);
    });

    test('entryWasSaved updates unsaved stream', () async {
      const entryId = 'test-entry-id';

      when(() => mockEditorDb.getLatestDraft(any(),
          lastSaved: any(named: 'lastSaved'))).thenAnswer((_) async => null);

      final stream =
          editorStateService.getUnsavedStream(entryId, testEpochDateTime);

      // The stream should first emit `false` (initial state),
      // then `false` again after entryWasSaved clears unsaved changes.
      final expectation = expectLater(stream, emitsInOrder([false, false]));

      editorStateService.editorStateById[entryId] =
          '{"ops":[{"insert":"test"}]}';

      final mockController = FakeQuillController(
        selection: const TextSelection.collapsed(offset: 0),
      );

      await editorStateService.entryWasSaved(
        id: entryId,
        lastSaved: testEpochDateTime,
        controller: mockController,
      );

      await expectation;
    });

    test('entryIsUnsaved returns true when entry has unsaved state', () {
      const entryId = 'test-entry-id';

      editorStateService.editorStateById[entryId] =
          '{"ops":[{"insert":"test"}]}';

      expect(editorStateService.entryIsUnsaved(entryId), true);
    });

    test('entryIsUnsaved returns false when entry has no unsaved state', () {
      expect(editorStateService.entryIsUnsaved('test-entry-id'), false);
    });

    test('getUnsavedStream emits true when draft exists', () async {
      const entryId = 'test-entry-id';
      const deltaJson = '{"ops":[{"insert":"draft content"}]}';

      final draftState = EditorDraftState(
        id: 'draft-id',
        entryId: entryId,
        status: 'DRAFT',
        createdAt: testEpochDateTime,
        delta: deltaJson,
        lastSaved: testEpochDateTime,
      );

      when(() => mockEditorDb.getLatestDraft(any(),
              lastSaved: any(named: 'lastSaved')))
          .thenAnswer((_) async => draftState);

      final stream =
          editorStateService.getUnsavedStream(entryId, testEpochDateTime);

      // The stream should emit `false` initially, then `true` when draft is loaded
      await expectLater(stream, emitsInOrder([false, true]));

      expect(editorStateService.editorStateById[entryId], deltaJson);
    });

    test('getUnsavedStream closes previous stream for same entry', () async {
      const entryId = 'test-entry-id';

      when(() => mockEditorDb.getLatestDraft(any(),
          lastSaved: any(named: 'lastSaved'))).thenAnswer((_) async => null);

      // Create first stream and subscribe to it
      final stream1 =
          editorStateService.getUnsavedStream(entryId, testEpochDateTime);

      var stream1Completed = false;
      final stream1Emissions = <bool>[];

      final subscription1 = stream1.listen(
        stream1Emissions.add,
        onDone: () {
          stream1Completed = true;
        },
      );

      // Wait for the first stream to emit its initial value
      await pumpEventQueue();
      expect(stream1Emissions, isNotEmpty);

      // Create second stream - this should close the first stream
      final stream2 =
          editorStateService.getUnsavedStream(entryId, testEpochDateTime);

      // Wait for stream1 to complete
      await pumpEventQueue();
      expect(stream1Completed, true);

      // Verify stream2 is active and can emit values
      final stream2Emissions = <bool>[];
      final subscription2 = stream2.listen(stream2Emissions.add);

      await pumpEventQueue();
      expect(stream2Emissions, isNotEmpty);

      // Clean up
      await subscription1.cancel();
      await subscription2.cancel();
    });
  });
}

class FakeDraftsQuery extends Fake implements Selectable<EditorDraftState> {
  @override
  Future<List<EditorDraftState>> get() async => [];
}

class FakeDraftsQueryWithData extends Fake
    implements Selectable<EditorDraftState> {
  FakeDraftsQueryWithData(this.data);
  final List<EditorDraftState> data;

  @override
  Future<List<EditorDraftState>> get() async => data;
}

class FakeJournalDbEntity extends Fake implements JournalDbEntity {
  FakeJournalDbEntity({required this.updatedAt});

  @override
  final DateTime updatedAt;
}
