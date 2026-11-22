import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';

import '../../../classes/task_document_fixtures.dart';
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

  test('taskDocumentRepositoryProvider builds the repository', () {
    expect(
      containerWith(const []).read(taskDocumentRepositoryProvider),
      isA<TaskDocumentRepository>(),
    );
  });
}
