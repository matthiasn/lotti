import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/service/task_document_agent_source.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../classes/task_document_fixtures.dart';
import '../../../helpers/fake_entry_controller.dart';
import '../../../helpers/fake_linked_entries_controller.dart';
import '../../../helpers/test_get_it.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  const taskId = 'task-1';

  ProviderContainer containerWith(List<JournalEntity> linked) {
    final container = ProviderContainer(
      overrides: [
        resolvedOutgoingLinkedEntriesProvider(
          taskId,
        ).overrideWith((ref) => linked),
        journalDbProvider.overrideWithValue(MockJournalDb()),
        persistenceLogicProvider.overrideWithValue(MockPersistenceLogic()),
        journalRepositoryProvider.overrideWithValue(MockJournalRepository()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    "taskDocumentsProvider lists the task's live documents oldest first, and "
    'nothing else it links',
    () {
      TaskDocumentEntry document(String id, {int second = 0, bool? deleted}) {
        final entry = taskDocumentEntry(
          clock: {'a': 1},
          id: id,
          deleted: deleted ?? false,
        );
        final at = taskDocFixtureEpoch.add(Duration(seconds: second));
        return entry.copyWith(meta: entry.meta.copyWith(createdAt: at));
      }

      final container = containerWith([
        document('newer', second: 20),
        testTextEntry,
        document('gone', second: 5, deleted: true),
        document('older', second: 10),
        taskDocumentVersionEntry(),
      ]);

      expect(
        container.read(taskDocumentsProvider(taskId)).map((d) => d.id),
        ['older', 'newer'],
      );
    },
  );

  group('taskDocumentsEnabledProvider', () {
    ProviderContainer flagContainer(Stream<bool> flag) {
      final container = ProviderContainer(
        overrides: [
          configFlagProvider(
            enableTaskDocumentsFlag,
          ).overrideWith((ref) => flag),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is off until the flag is read', () {
      final container = flagContainer(const Stream.empty())
        ..listen(taskDocumentsEnabledProvider, (_, _) {});

      expect(container.read(taskDocumentsEnabledProvider), isFalse);
    });

    test('follows the flag', () async {
      for (final value in [true, false]) {
        final container = flagContainer(Stream.value(value))
          ..listen(taskDocumentsEnabledProvider, (_, _) {});
        await container.read(
          configFlagProvider(enableTaskDocumentsFlag).future,
        );

        expect(container.read(taskDocumentsEnabledProvider), value);
      }
    });
  });

  group('taskDocumentGoneProvider', () {
    // The entry controller reads its services from the locator.
    setUp(
      () => setUpTestGetIt(
        additionalSetup: () => getIt.registerSingleton<EditorStateService>(
          MockEditorStateService(),
        ),
      ),
    );
    tearDown(tearDownTestGetIt);

    const key = (taskId: taskId, documentId: 'doc-brief');
    final document = taskDocumentEntry(clock: {'a': 1}, id: 'doc-brief');
    final link = EntryLink.basic(
      id: 'link-1',
      fromId: taskId,
      toId: 'doc-brief',
      createdAt: taskDocFixtureEpoch,
      updatedAt: taskDocFixtureEpoch,
      vectorClock: null,
    );

    /// A container whose task links resolve to [links] — or never, when
    /// null — and whose linked document resolves to [entry], or never
    /// without one.
    ProviderContainer goneContainer({
      List<EntryLink>? links,
      JournalEntity? entry,
      bool entryLoads = true,
    }) {
      final container = ProviderContainer(
        overrides: [
          linkedEntriesControllerProvider(taskId).overrideWith(
            () => links == null
                ? _NeverLinkedEntriesController()
                : FakeLinkedEntriesController(links: links),
          ),
          entryControllerProvider('doc-brief').overrideWith(
            () => entry != null && entryLoads
                ? FakeEntryController(entry)
                : _NeverEntryController(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(taskDocumentGoneProvider(key), (_, _) {});
      return container;
    }

    Future<bool> settled(ProviderContainer container) async {
      await pumpEventQueue();
      return container.read(taskDocumentGoneProvider(key));
    }

    test("is false while the task's links are still loading", () async {
      expect(await settled(goneContainer()), isFalse);
    });

    test('is false while the linked document is still loading', () async {
      expect(
        await settled(goneContainer(links: [link], entryLoads: false)),
        isFalse,
      );
    });

    test('is false for a live document of the task', () async {
      expect(
        await settled(goneContainer(links: [link], entry: document)),
        isFalse,
      );
    });

    test('is true once the links are read and name no such document', () async {
      expect(await settled(goneContainer(links: const [])), isTrue);
    });

    test('is true once the linked document is read as deleted', () async {
      final deleted = taskDocumentEntry(
        clock: {'a': 2},
        id: 'doc-brief',
        deleted: true,
      );
      expect(
        await settled(goneContainer(links: [link], entry: deleted)),
        isTrue,
      );
    });
  });

  test('taskDocumentRepositoryProvider builds the repository', () {
    expect(
      containerWith(const []).read(taskDocumentRepositoryProvider),
      isA<TaskDocumentRepository>(),
    );
  });

  test(
    'taskDocumentAgentSourceProvider is the source the agent is wired to',
    () {
      expect(
        containerWith(const []).read(taskDocumentAgentSourceProvider),
        isA<TaskDocumentAgentSource>(),
      );
    },
  );

  group('one document -', () {
    const key = (taskId: taskId, documentId: 'doc-1');
    late MockTaskDocumentRepository repository;
    late ProviderContainer container;
    late _Documents documents;

    final v1 = taskDocumentVersionEntry(id: 'v1', documentId: 'doc-1');
    final v2 = taskDocumentVersionEntry(
      number: 2,
      id: 'v2',
      documentId: 'doc-1',
    );
    final atV1 = taskDocumentEntry(
      clock: {'a': 1},
      id: 'doc-1',
      current: v1.ref,
    );

    setUpAll(() => registerFallbackValue(atV1));

    setUp(() {
      repository = MockTaskDocumentRepository();
      when(() => repository.currentVersion(any())).thenAnswer(
        (invocation) async =>
            (invocation.positionalArguments.first as TaskDocumentEntry)
                    .data
                    .current
                    ?.id ==
                'v2'
            ? v2
            : v1,
      );
      when(
        () => repository.versions('doc-1'),
      ).thenAnswer((_) async => [v2, v1]);
      container = ProviderContainer(
        overrides: [
          taskDocumentRepositoryProvider.overrideWithValue(repository),
          taskDocumentsProvider(
            taskId,
          ).overrideWith((ref) => ref.watch(_documentsProvider)),
        ],
      );
      addTearDown(container.dispose);
      documents = container.read(_documentsProvider.notifier)..state = [atV1];
    });

    test('taskDocumentProvider follows the document, and is null once it is '
        'gone', () {
      final sub = container.listen(taskDocumentProvider(key), (_, _) {});
      addTearDown(sub.close);
      expect(sub.read(), atV1);

      documents.state = [];
      expect(container.read(taskDocumentProvider(key)), isNull);
    });

    test(
      'the current version is read again when the document moves to '
      'another version, not when it is only renamed, and the previous one '
      'stays while the next loads',
      () async {
        final sub = container.listen(
          taskDocumentCurrentVersionProvider(key),
          (_, _) {},
        );
        addTearDown(sub.close);
        expect(
          await container.read(taskDocumentCurrentVersionProvider(key).future),
          v1,
        );

        documents.state = [
          atV1.copyWith(data: atV1.data.copyWith(title: 'Renamed')),
        ];
        await container.read(taskDocumentCurrentVersionProvider(key).future);
        verify(() => repository.currentVersion(any())).called(1);

        documents.state = [
          atV1.copyWith(data: atV1.data.copyWith(current: v2.ref)),
        ];
        // While the new version loads, the one on show is kept.
        expect(sub.read().value, v1);
        expect(
          await container.read(taskDocumentCurrentVersionProvider(key).future),
          v2,
        );
      },
    );

    test('the versions are listed newest first, and listed again when the '
        'document moves to another version', () async {
      final sub = container.listen(
        taskDocumentVersionsProvider(key),
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        await container.read(taskDocumentVersionsProvider(key).future),
        [v2, v1],
      );

      documents.state = [
        atV1.copyWith(data: atV1.data.copyWith(current: v2.ref)),
      ];
      await container.read(taskDocumentVersionsProvider(key).future);
      verify(() => repository.versions('doc-1')).called(2);
    });
  });
}

final _documentsProvider =
    NotifierProvider<_Documents, List<TaskDocumentEntry>>(_Documents.new);

class _Documents extends Notifier<List<TaskDocumentEntry>> {
  @override
  List<TaskDocumentEntry> build() => const [];
}

/// Task links that never finish loading.
class _NeverLinkedEntriesController extends LinkedEntriesController {
  @override
  Future<List<EntryLink>> build() => Completer<List<EntryLink>>().future;
}

/// An entry that never finishes loading.
class _NeverEntryController extends EntryController {
  @override
  Future<EntryState?> build() => Completer<EntryState?>().future;
}
