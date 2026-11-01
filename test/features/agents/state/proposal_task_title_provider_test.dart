import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/proposal_task_title_provider.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

const _taskId = 'census';

void main() {
  late MockJournalDb db;
  late StreamController<Set<String>> updates;
  late ProviderContainer container;

  setUp(() {
    db = MockJournalDb();
    updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    final notifications = MockUpdateNotifications();
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    container = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(db),
        updateNotificationsProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
  });

  void stubEntity(JournalEntity? entity) =>
      when(() => db.journalEntityById(_taskId)).thenAnswer((_) async => entity);

  Future<String?> read() {
    final sub = container.listen(proposalTaskTitleProvider(_taskId), (_, _) {});
    addTearDown(sub.close);
    return container.read(proposalTaskTitleProvider(_taskId).future);
  }

  test("reads the task's title, trimmed", () async {
    stubEntity(
      TestTaskFactory.create(id: _taskId, title: '  Colony census export '),
    );

    expect(await read(), 'Colony census export');
  });

  test('is null for a deleted task, a blank title, an entry that is not a '
      'task, or nothing at all', () async {
    final task = TestTaskFactory.create(id: _taskId);
    for (final entity in <JournalEntity?>[
      task.copyWith(meta: task.meta.copyWith(deletedAt: testFixedDate)),
      TestTaskFactory.create(id: _taskId, title: '   '),
      JournalEntry(
        meta: TestMetadataFactory.create(id: _taskId),
        entryText: const EntryText(plainText: 'a note'),
      ),
      null,
    ]) {
      stubEntity(entity);
      container.invalidate(proposalTaskTitleProvider(_taskId));

      expect(await read(), isNull, reason: '$entity');
    }
  });

  test('reads again when a notification names the task', () async {
    stubEntity(TestTaskFactory.create(id: _taskId, title: 'Before'));
    await read();

    stubEntity(TestTaskFactory.create(id: _taskId, title: 'After'));
    updates.add({_taskId});
    await pumpEventQueue();

    expect(
      await container.read(proposalTaskTitleProvider(_taskId).future),
      'After',
    );
  });
}
