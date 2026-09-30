import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/platform.dart' as platform_utils;
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import '../widget_test_utils.dart' show setUpTestGetIt, tearDownTestGetIt;

enum _GeneratedEditorStateOperationKind {
  saveTempState,
  saveSelection,
  entryWasSaved,
}

class _GeneratedEditorStateOperation {
  const _GeneratedEditorStateOperation({
    required this.kind,
    required this.entrySlot,
    required this.seed,
  });

  final _GeneratedEditorStateOperationKind kind;
  final int entrySlot;
  final int seed;

  String get entryId => 'generated-entry-${entrySlot % 3}';

  DateTime get lastSaved => DateTime(2024, 3, 15, 10, seed % 60);

  String get deltaJson => '{"ops":[{"insert":"generated-$seed"}]}';

  TextSelection get selection => TextSelection.collapsed(
    offset: seed % 12,
  );

  @override
  String toString() {
    return '_GeneratedEditorStateOperation('
        'kind: $kind, entrySlot: $entrySlot, seed: $seed)';
  }
}

class _GeneratedEditorStateScenario {
  const _GeneratedEditorStateScenario({required this.operations});

  final List<_GeneratedEditorStateOperation> operations;

  @override
  String toString() {
    return '_GeneratedEditorStateScenario(operations: $operations)';
  }
}

extension _AnyGeneratedEditorStateScenario on glados.Any {
  glados.Generator<_GeneratedEditorStateOperationKind>
  get editorStateOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedEditorStateOperationKind.values);

  glados.Generator<_GeneratedEditorStateOperation> get editorStateOperation =>
      glados.CombinableAny(this).combine3(
        editorStateOperationKind,
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedEditorStateOperationKind kind,
          int entrySlot,
          int seed,
        ) => _GeneratedEditorStateOperation(
          kind: kind,
          entrySlot: entrySlot,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedEditorStateScenario> get editorStateScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(0, 45, editorStateOperation)
          .map(
            (operations) =>
                _GeneratedEditorStateScenario(operations: operations),
          );
}

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

    setUp(() async {
      mockJournalDb = MockJournalDb();
      mockEditorDb = MockEditorDb();

      when(() => mockEditorDb.allDrafts()).thenAnswer(
        (_) => FakeDraftsQuery(),
      );

      when(
        () => mockEditorDb.insertDraftState(
          entryId: any(named: 'entryId'),
          lastSaved: any(named: 'lastSaved'),
          draftDeltaJson: any(named: 'draftDeltaJson'),
        ),
      ).thenAnswer((_) async => 1);

      when(
        () => mockEditorDb.setDraftSaved(
          entryId: any(named: 'entryId'),
          lastSaved: any(named: 'lastSaved'),
        ),
      ).thenAnswer((_) async => 1);

      // Mock entityById and the bulk variant the new init() coalesces to.
      when(() => mockJournalDb.entityById(any())).thenAnswer((_) async => null);
      when(
        () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
      ).thenAnswer((_) => FakeJournalEntitiesQuery(const <JournalDbEntity>[]));

      // Central GetIt harness; swap in this file's JournalDb mock and add
      // the EditorDb registration on top.
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(mockJournalDb)
            ..registerSingleton<EditorDb>(mockEditorDb);
        },
      );

      editorStateService = EditorStateService();
    });

    tearDown(() async {
      EasyDebounce.cancelAll();
      await tearDownTestGetIt();
    });

    glados.Glados(
      glados.any.editorStateScenario,
      // 100 runs is the Glados default and adequate here: the input space is
      // bounded by 3 entry ids x 3 operation kinds.
      glados.ExploreConfig(),
    ).test('matches generated edit and save sequence invariants', (scenario) {
      fakeAsync((async) {
        final service = EditorStateService();
        async.flushMicrotasks();

        when(
          () => mockEditorDb.getLatestDraft(
            any(),
            lastSaved: any(named: 'lastSaved'),
          ),
        ).thenAnswer((_) async => null);

        const entryIds = [
          'generated-entry-0',
          'generated-entry-1',
          'generated-entry-2',
        ];
        final emissionsById = {
          for (final id in entryIds) id: <bool>[],
        };
        final expectedEmissionsById = {
          for (final id in entryIds) id: <bool>[false],
        };
        final subscriptions = [
          for (final id in entryIds)
            service
                .getUnsavedStream(id, testEpochDateTime)
                .listen(emissionsById[id]!.add),
        ];
        async.flushMicrotasks();

        final expectedDeltaById = <String, String>{};
        final expectedSelectionById = <String, TextSelection>{};

        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case _GeneratedEditorStateOperationKind.saveTempState:
              service.saveTempState(
                id: operation.entryId,
                lastSaved: operation.lastSaved,
                json: operation.deltaJson,
              );
              expectedDeltaById[operation.entryId] = operation.deltaJson;
              expectedSelectionById.remove(operation.entryId);
              expectedEmissionsById[operation.entryId]!.add(true);
              async
                ..elapse(Duration.zero)
                ..flushMicrotasks();
            case _GeneratedEditorStateOperationKind.saveSelection:
              service.saveSelection(
                operation.entryId,
                operation.selection,
              );
              expectedSelectionById[operation.entryId] = operation.selection;
            case _GeneratedEditorStateOperationKind.entryWasSaved:
              unawaited(
                service.entryWasSaved(
                  id: operation.entryId,
                  lastSaved: operation.lastSaved,
                  controller: FakeQuillController(
                    selection: operation.selection,
                  ),
                ),
              );
              expectedDeltaById.remove(operation.entryId);
              expectedSelectionById[operation.entryId] = operation.selection;
              expectedEmissionsById[operation.entryId]!.add(false);
              async.flushMicrotasks();
          }
        }

        expect(
          service.editorStateById,
          expectedDeltaById,
          reason: scenario.toString(),
        );
        for (final id in entryIds) {
          expect(
            service.entryIsUnsaved(id),
            expectedDeltaById.containsKey(id),
            reason: '$scenario for $id',
          );
          expect(
            service.getDelta(id),
            expectedDeltaById[id],
            reason: '$scenario for $id',
          );
          expect(
            service.getSelection(id),
            expectedSelectionById[id],
            reason: '$scenario for $id',
          );
          expect(
            emissionsById[id],
            expectedEmissionsById[id],
            reason: '$scenario for $id',
          );
        }

        for (final subscription in subscriptions) {
          unawaited(subscription.cancel());
        }
        EasyDebounce.cancelAll();
        async.flushMicrotasks();
      });
    }, tags: 'glados');

    test('init populates editorStateById with matching drafts', () async {
      final testTime = DateTime(2024, 3, 15, 10, 30);
      final testEntity = FakeJournalDbEntity(
        id: 'test-entry-id',
        updatedAt: testTime,
      );

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

      when(
        () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
      ).thenAnswer(
        (_) => FakeJournalEntitiesQuery(<JournalDbEntity>[testEntity]),
      );

      final service = EditorStateService();
      await service.init();

      expect(service.editorStateById['test-entry-id'], isNotNull);
      expect(
        service.editorStateById['test-entry-id'],
        '{"ops":[{"insert":"test"}]}',
      );
    });

    test('init skips drafts when updatedAt does not match', () async {
      final testEntity = FakeJournalDbEntity(
        id: 'test-entry-id',
        updatedAt: DateTime(2025),
      );

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

      when(
        () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
      ).thenAnswer(
        (_) => FakeJournalEntitiesQuery(<JournalDbEntity>[testEntity]),
      );

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

      when(
        () => mockEditorDb.getLatestDraft(
          any(),
          lastSaved: any(named: 'lastSaved'),
        ),
      ).thenAnswer((_) async => null);

      final stream = editorStateService.getUnsavedStream(
        entryId,
        testEpochDateTime,
      );

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

      when(
        () => mockEditorDb.getLatestDraft(
          any(),
          lastSaved: any(named: 'lastSaved'),
        ),
      ).thenAnswer((_) async => null);

      final stream = editorStateService.getUnsavedStream(
        entryId,
        testEpochDateTime,
      );

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

    test(
      'dropDraft clears in-memory state and marks the draft saved',
      () async {
        const entryId = 'test-entry-id';

        editorStateService.editorStateById[entryId] =
            '{"ops":[{"insert":"test"}]}';
        editorStateService.selectionById[entryId] =
            const TextSelection.collapsed(offset: 0);

        await editorStateService.dropDraft(
          id: entryId,
          lastSaved: testEpochDateTime,
        );

        expect(editorStateService.editorStateById[entryId], isNull);
        expect(editorStateService.selectionById[entryId], isNull);
        expect(editorStateService.entryIsUnsaved(entryId), false);
        verify(
          () => mockEditorDb.setDraftSaved(
            entryId: entryId,
            lastSaved: testEpochDateTime,
          ),
        ).called(1);
      },
    );

    test('dropDraft emits false on the unsaved stream', () async {
      const entryId = 'test-entry-id';

      when(
        () => mockEditorDb.getLatestDraft(
          any(),
          lastSaved: any(named: 'lastSaved'),
        ),
      ).thenAnswer((_) async => null);

      final stream = editorStateService.getUnsavedStream(
        entryId,
        testEpochDateTime,
      );
      final expectation = expectLater(stream, emitsInOrder([false, false]));

      editorStateService.editorStateById[entryId] =
          '{"ops":[{"insert":"test"}]}';

      await editorStateService.dropDraft(
        id: entryId,
        lastSaved: testEpochDateTime,
      );

      await expectation;
    });

    group('rebaseDraft', () {
      final typedAgainst = DateTime(2026, 9, 28, 14);
      final newVersion = DateTime(2026, 9, 28, 14, 5);

      setUp(() {
        when(
          () => mockEditorDb.rebaseDraft(
            entryId: any(named: 'entryId'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).thenAnswer((_) async => 1);
        // The real two-second debounce, so a write is actually pending.
        final wasTestEnv = platform_utils.isTestEnv;
        platform_utils.isTestEnv = false;
        addTearDown(() => platform_utils.isTestEnv = wasTestEnv);
      });

      test('moves the persisted draft rows onto the new version', () async {
        await editorStateService.rebaseDraft(
          id: 'entry-a',
          from: typedAgainst,
          to: newVersion,
        );

        verify(
          () => mockEditorDb.rebaseDraft(
            entryId: 'entry-a',
            from: typedAgainst,
            to: newVersion,
          ),
        ).called(1);
      });

      test('a debounced write still pending lands under the new version', () {
        fakeAsync((async) {
          editorStateService
            ..saveTempState(
              id: 'entry-a',
              lastSaved: typedAgainst,
              json: '{"ops":[{"insert":"a"}]}',
            )
            ..rebaseDraft(id: 'entry-a', from: typedAgainst, to: newVersion);
          async.flushMicrotasks();
          verifyNever(
            () => mockEditorDb.insertDraftState(
              entryId: any(named: 'entryId'),
              lastSaved: any(named: 'lastSaved'),
              draftDeltaJson: any(named: 'draftDeltaJson'),
            ),
          );
          async.elapse(const Duration(seconds: 3));

          verify(
            () => mockEditorDb.insertDraftState(
              entryId: 'entry-a',
              lastSaved: newVersion,
              draftDeltaJson: '{"ops":[{"insert":"a"}]}',
            ),
          ).called(1);
        });
      });

      test('leaves a pending write typed against another version alone', () {
        fakeAsync((async) {
          final other = DateTime(2026, 9, 28, 13);
          editorStateService
            ..saveTempState(
              id: 'entry-a',
              lastSaved: other,
              json: '{"ops":[{"insert":"a"}]}',
            )
            ..rebaseDraft(id: 'entry-a', from: typedAgainst, to: newVersion);
          async.flushMicrotasks();
          verifyNever(
            () => mockEditorDb.insertDraftState(
              entryId: any(named: 'entryId'),
              lastSaved: any(named: 'lastSaved'),
              draftDeltaJson: any(named: 'draftDeltaJson'),
            ),
          );
          async.elapse(const Duration(seconds: 3));

          verify(
            () => mockEditorDb.insertDraftState(
              entryId: 'entry-a',
              lastSaved: other,
              draftDeltaJson: any(named: 'draftDeltaJson'),
            ),
          ).called(1);
        });
      });
    });

    group('draftVersion and draftOn', () {
      final typedAgainst = DateTime(2026, 9, 28, 14);
      const draft = r'[{"insert":"typed\n"}]';

      test('hold nothing for an entry without a draft', () {
        expect(editorStateService.draftVersion('entry-a'), isNull);
        expect(editorStateService.draftOn('entry-a', typedAgainst), isNull);
      });

      test('a typed draft is on the version it was typed against', () {
        editorStateService.saveTempState(
          id: 'entry-a',
          lastSaved: typedAgainst,
          json: draft,
        );

        expect(editorStateService.draftVersion('entry-a'), typedAgainst);
        expect(editorStateService.draftOn('entry-a', typedAgainst), draft);
      });

      test('draftOn withholds a draft typed against another version', () {
        editorStateService.saveTempState(
          id: 'entry-a',
          lastSaved: typedAgainst,
          json: draft,
        );

        expect(
          editorStateService.draftOn(
            'entry-a',
            typedAgainst.add(const Duration(minutes: 5)),
          ),
          isNull,
        );
      });

      test('a draft restored at startup is on the version it was typed '
          'against', () async {
        when(() => mockEditorDb.allDrafts()).thenAnswer(
          (_) => FakeDraftsQueryWithData([
            EditorDraftState(
              id: 'draft-id',
              entryId: 'entry-a',
              status: 'DRAFT',
              createdAt: testEpochDateTime,
              delta: draft,
              lastSaved: typedAgainst,
            ),
          ]),
        );
        when(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).thenAnswer(
          (_) => FakeJournalEntitiesQuery(<JournalDbEntity>[
            FakeJournalDbEntity(id: 'entry-a', updatedAt: typedAgainst),
          ]),
        );

        final service = EditorStateService();
        await service.init();

        expect(service.draftOn('entry-a', typedAgainst), draft);
      });

      test('a draft loaded for an open editor is on the version it was '
          'typed against', () async {
        when(
          () => mockEditorDb.getLatestDraft(
            'entry-a',
            lastSaved: typedAgainst,
          ),
        ).thenAnswer(
          (_) async => EditorDraftState(
            id: 'draft-id',
            entryId: 'entry-a',
            status: 'DRAFT',
            createdAt: testEpochDateTime,
            delta: draft,
            lastSaved: typedAgainst,
          ),
        );

        await expectLater(
          editorStateService.getUnsavedStream('entry-a', typedAgainst),
          emitsInOrder([false, true]),
        );

        expect(editorStateService.draftOn('entry-a', typedAgainst), draft);
      });
    });

    group('draftWasStored', () {
      final typedAgainst = DateTime(2026, 9, 28, 14);
      final storedAs = DateTime(2026, 9, 28, 14, 5);
      const draft = r'[{"insert":"typed\n"}]';
      const typedMeanwhile = r'[{"insert":"typed more\n"}]';

      setUp(() {
        when(
          () => mockEditorDb.rebaseDraft(
            entryId: any(named: 'entryId'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).thenAnswer((_) async => 1);
        // The real two-second debounce, so a write is actually pending.
        final wasTestEnv = platform_utils.isTestEnv;
        platform_utils.isTestEnv = false;
        addTearDown(() => platform_utils.isTestEnv = wasTestEnv);
      });

      test('the stored draft is saved: forgotten, its rows marked saved '
          'under either version, and the editor told', () {
        fakeAsync((async) {
          when(
            () => mockEditorDb.getLatestDraft(
              any(),
              lastSaved: any(named: 'lastSaved'),
            ),
          ).thenAnswer((_) async => null);
          final unsaved = <bool>[];
          editorStateService
              .getUnsavedStream('entry-a', typedAgainst)
              .listen(unsaved.add);
          editorStateService
            ..saveTempState(
              id: 'entry-a',
              lastSaved: typedAgainst,
              json: draft,
            )
            ..draftWasStored(
              id: 'entry-a',
              draft: draft,
              from: typedAgainst,
              to: storedAs,
            );
          async.elapse(const Duration(seconds: 3));

          expect(editorStateService.entryIsUnsaved('entry-a'), isFalse);
          expect(editorStateService.draftVersion('entry-a'), isNull);
          expect(editorStateService.storedDraftVersion('entry-a'), storedAs);
          expect(unsaved.last, isFalse);
          verify(
            () => mockEditorDb.setDraftSaved(
              entryId: 'entry-a',
              lastSaved: typedAgainst,
            ),
          ).called(1);
          verify(
            () => mockEditorDb.setDraftSaved(
              entryId: 'entry-a',
              lastSaved: storedAs,
            ),
          ).called(1);
          // The debounced write of the stored draft never lands.
          verifyNever(
            () => mockEditorDb.insertDraftState(
              entryId: any(named: 'entryId'),
              lastSaved: any(named: 'lastSaved'),
              draftDeltaJson: any(named: 'draftDeltaJson'),
            ),
          );
        });
      });

      test('a draft typed while the write ran stays unsaved, moved onto '
          'the stored version', () {
        fakeAsync((async) {
          editorStateService
            ..saveTempState(
              id: 'entry-a',
              lastSaved: typedAgainst,
              json: typedMeanwhile,
            )
            ..draftWasStored(
              id: 'entry-a',
              draft: draft,
              from: typedAgainst,
              to: storedAs,
            );
          async.elapse(const Duration(seconds: 3));

          expect(editorStateService.entryIsUnsaved('entry-a'), isTrue);
          expect(
            editorStateService.draftOn('entry-a', storedAs),
            typedMeanwhile,
          );
          expect(editorStateService.storedDraftVersion('entry-a'), isNull);
          verifyNever(
            () => mockEditorDb.setDraftSaved(
              entryId: any(named: 'entryId'),
              lastSaved: any(named: 'lastSaved'),
            ),
          );
          verify(
            () => mockEditorDb.rebaseDraft(
              entryId: 'entry-a',
              from: typedAgainst,
              to: storedAs,
            ),
          ).called(1);
          verify(
            () => mockEditorDb.insertDraftState(
              entryId: 'entry-a',
              lastSaved: storedAs,
              draftDeltaJson: typedMeanwhile,
            ),
          ).called(1);
        });
      });

      group('the stored version is forgotten', () {
        /// Stores [draft] through [EditorStateService.draftWasStored], so
        /// the stored version is recorded.
        Future<void> storeDraft() async {
          editorStateService.saveTempState(
            id: 'entry-a',
            lastSaved: typedAgainst,
            json: draft,
          );
          await editorStateService.draftWasStored(
            id: 'entry-a',
            draft: draft,
            from: typedAgainst,
            to: storedAs,
          );
          expect(editorStateService.storedDraftVersion('entry-a'), storedAs);
        }

        test('when the entry is saved', () async {
          await storeDraft();

          await editorStateService.entryWasSaved(
            id: 'entry-a',
            lastSaved: storedAs,
            controller: FakeQuillController(),
          );

          expect(editorStateService.storedDraftVersion('entry-a'), isNull);
        });

        test('when the draft is discarded', () async {
          await storeDraft();

          await editorStateService.dropDraft(
            id: 'entry-a',
            lastSaved: storedAs,
          );

          expect(editorStateService.storedDraftVersion('entry-a'), isNull);
        });

        test('when every draft is reset', () async {
          await storeDraft();

          editorStateService.resetDrafts();

          expect(editorStateService.storedDraftVersion('entry-a'), isNull);
        });
      });
    });

    test(
      'resetDrafts forgets every draft, cancels pending writes and tells '
      'open editors they are saved',
      () {
        fakeAsync((async) {
          when(
            () => mockEditorDb.getLatestDraft(
              any(),
              lastSaved: any(named: 'lastSaved'),
            ),
          ).thenAnswer((_) async => null);
          final emitted = <bool>[];
          editorStateService
              .getUnsavedStream('entry-a', testEpochDateTime)
              .listen(emitted.add);
          editorStateService
            ..saveTempState(
              id: 'entry-a',
              lastSaved: testEpochDateTime,
              json: '{"ops":[{"insert":"a"}]}',
            )
            ..saveTempState(
              id: 'entry-b',
              lastSaved: testEpochDateTime,
              json: '{"ops":[{"insert":"b"}]}',
            )
            ..saveSelection(
              'entry-a',
              const TextSelection.collapsed(offset: 1),
            );
          // The test environment debounces with zero delay, so stand in a
          // write that is still pending, keyed the way the service keys it.
          var pendingWriteFired = false;
          EasyDebounce.debounce(
            'persistDraftState-entry-a',
            const Duration(seconds: 2),
            () => pendingWriteFired = true,
          );
          async.flushMicrotasks();

          editorStateService.resetDrafts();
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 3));

          expect(editorStateService.getDelta('entry-a'), isNull);
          expect(editorStateService.getDelta('entry-b'), isNull);
          expect(editorStateService.getSelection('entry-a'), isNull);
          expect(editorStateService.entryIsUnsaved('entry-b'), isFalse);
          expect(pendingWriteFired, isFalse);
          expect(emitted.last, isFalse);
        });
      },
    );

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

      when(
        () => mockEditorDb.getLatestDraft(
          any(),
          lastSaved: any(named: 'lastSaved'),
        ),
      ).thenAnswer((_) async => draftState);

      final stream = editorStateService.getUnsavedStream(
        entryId,
        testEpochDateTime,
      );

      // The stream should emit `false` initially, then `true` when draft is loaded
      await expectLater(stream, emitsInOrder([false, true]));

      expect(editorStateService.editorStateById[entryId], deltaJson);
    });

    test('getUnsavedStream closes previous stream for same entry', () async {
      const entryId = 'test-entry-id';

      when(
        () => mockEditorDb.getLatestDraft(
          any(),
          lastSaved: any(named: 'lastSaved'),
        ),
      ).thenAnswer((_) async => null);

      // Create first stream and subscribe to it
      final stream1 = editorStateService.getUnsavedStream(
        entryId,
        testEpochDateTime,
      );

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
      final stream2 = editorStateService.getUnsavedStream(
        entryId,
        testEpochDateTime,
      );

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
  FakeJournalDbEntity({required this.id, required this.updatedAt});

  @override
  final String id;

  @override
  final DateTime updatedAt;
}

class FakeJournalEntitiesQuery extends Fake
    implements Selectable<JournalDbEntity> {
  FakeJournalEntitiesQuery(this.data);
  final List<JournalDbEntity> data;

  @override
  Future<List<JournalDbEntity>> get() async => data;
}
