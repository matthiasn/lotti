import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

typedef ChecklistChange = ChecklistData Function(ChecklistData stored);
typedef ChecklistIdsChange = List<String> Function(List<String> stored);

Checklist makeChecklist(
  String id,
  List<String> items, {
  String? title,
}) => Checklist(
  meta: Metadata(
    id: id,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    dateFrom: DateTime(2025),
    dateTo: DateTime(2025),
  ),
  data: ChecklistData(
    title: title ?? id,
    linkedChecklistItems: items,
    linkedTasks: const ['task-1'],
  ),
);

ChecklistItem makeItem(
  String id, {
  String fromChecklistId = 'checklist-1',
  String title = 'New Item',
}) => ChecklistItem(
  meta: Metadata(
    id: id,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    dateFrom: DateTime(2025),
    dateTo: DateTime(2025),
  ),
  data: ChecklistItemData(
    title: title,
    isChecked: false,
    linkedChecklists: [fromChecklistId],
  ),
);

void main() {
  late MockJournalDb mockDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockJournalRepository mockJournalRepository;
  late MockChecklistRepository mockChecklistRepository;
  late MockDomainLogger mockDomainLogger;
  late StreamController<Set<String>> updateStreamController;

  /// The checklists as the database holds them, keyed by id. The
  /// `updateChecklist` stub applies each change to the entry here — as the
  /// repository applies it to the stored row — so a test can store a change
  /// the controller has not been notified of yet.
  late Map<String, Checklist> stored;

  final testChecklist = makeChecklist(
    'checklist-1',
    const ['item-1', 'item-2'],
    title: 'Test Checklist',
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockJournalRepository = MockJournalRepository();
    mockChecklistRepository = MockChecklistRepository();
    mockDomainLogger = MockDomainLogger();
    updateStreamController = StreamController<Set<String>>.broadcast();
    stored = {'checklist-1': testChecklist};

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockDb)
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockDomainLogger);
      },
    );

    // The controller reads its checklist as stored — including when it
    // re-reads the row after a repository write.
    when(
      () => mockDb.journalEntityById(any()),
    ).thenAnswer(
      (invocation) async => stored[invocation.positionalArguments[0]],
    );
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);
    when(
      () => mockJournalRepository.deleteJournalEntity(any()),
    ).thenAnswer((_) async => true);
    when(
      () => mockChecklistRepository.deleteChecklist(
        checklistId: any(named: 'checklistId'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockChecklistRepository.updateChecklist(
        checklistId: any(named: 'checklistId'),
        change: any(named: 'change'),
      ),
    ).thenAnswer((invocation) async {
      final checklistId = invocation.namedArguments[#checklistId] as String;
      final change = invocation.namedArguments[#change] as ChecklistChange;
      final current = stored[checklistId];
      if (current == null) return null;
      final next = current.copyWith(data: change(current.data));
      stored[checklistId] = next;
      return next;
    });
    when(
      () => mockChecklistRepository.updateTaskChecklistIds(
        taskId: any(named: 'taskId'),
        change: any(named: 'change'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await updateStreamController.close();
    await tearDownTestGetIt();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        checklistRepositoryProvider.overrideWithValue(mockChecklistRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Builds a container and awaits the initial state of the controller for
  /// [params].
  Future<ProviderContainer> loaded([
    ChecklistParams params = (id: 'checklist-1', taskId: 'task-1'),
  ]) async {
    final container = makeContainer();
    await container.read(checklistControllerProvider(params).future);
    return container;
  }

  ChecklistController notifierOf(
    ProviderContainer container, [
    ChecklistParams params = (id: 'checklist-1', taskId: 'task-1'),
  ]) => container.read(checklistControllerProvider(params).notifier);

  Checklist? stateOf(
    ProviderContainer container, [
    ChecklistParams params = (id: 'checklist-1', taskId: 'task-1'),
  ]) => container.read(checklistControllerProvider(params)).value;

  /// Stores [checklist] and serves it from the database, as if it had been
  /// written before the controller loads.
  void seed(Checklist checklist) => stored[checklist.id] = checklist;

  /// Stores [items] for `checklist-1` without notifying the controller — an
  /// item another device synced in after the screen last read the checklist.
  void storeMeanwhile(List<String> items) {
    final current = stored['checklist-1']!;
    stored['checklist-1'] = current.copyWith(
      data: current.data.copyWith(linkedChecklistItems: items),
    );
  }

  List<String> storedItems([String id = 'checklist-1']) =>
      stored[id]!.data.linkedChecklistItems;

  void verifyNoChecklistWrite() => verifyNever(
    () => mockChecklistRepository.updateChecklist(
      checklistId: any(named: 'checklistId'),
      change: any(named: 'change'),
    ),
  );

  group('debugInsertItemAt (pure insertion/move logic)', () {
    glados.Glados3(
      glados.IntAnys(glados.any).intInRange(0, 6),
      glados.IntAnys(glados.any).intInRange(-2, 9),
      glados.IntAnys(glados.any).intInRange(0, 4),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'inserted exactly once, never duplicated, order of others preserved',
      (existingCount, rawTarget, mode) {
        final controller = ChecklistController(
          (id: 'checklist-1', taskId: null),
        );
        final existing = List.generate(existingCount, (i) => 'item-$i');
        // mode 0: explicit index; 1: after a target item (or appended when
        // the target is missing); 2: append (no target); 3: move an
        // EXISTING id instead of inserting a new one.
        final itemId = mode == 3 && existing.isNotEmpty
            ? existing[rawTarget.abs() % existing.length]
            : 'item-new';
        final targetItemId = mode == 1
            ? (existing.isNotEmpty && rawTarget >= 0
                  ? existing[rawTarget % existing.length]
                  : 'missing-item')
            : null;

        final result = controller.debugInsertItemAt(
          existing,
          itemId,
          targetIndex: mode == 0 ? rawTarget : null,
          targetItemId: targetItemId,
        );
        final reason =
            'existing=$existing itemId=$itemId mode=$mode raw=$rawTarget';

        // The id appears exactly once.
        expect(
          result.where((id) => id == itemId),
          hasLength(1),
          reason: reason,
        );
        // Length: +1 for a new id, unchanged for a move.
        expect(
          result.length,
          existing.contains(itemId) ? existing.length : existing.length + 1,
          reason: reason,
        );
        // Relative order of all other items is preserved.
        expect(
          result.where((id) => id != itemId).toList(),
          existing.where((id) => id != itemId).toList(),
          reason: reason,
        );
        // Mode-specific placement contracts.
        if (mode == 0) {
          final others = existing.toList()..remove(itemId);
          expect(
            result.indexOf(itemId),
            rawTarget.clamp(0, others.length),
            reason: reason,
          );
        }
        if (mode == 1 && targetItemId != null) {
          final targetIdx = result.indexOf(targetItemId);
          if (targetIdx != -1) {
            expect(result.indexOf(itemId), targetIdx + 1, reason: reason);
          } else {
            expect(result.last, itemId, reason: reason);
          }
        }
        if (mode == 2) {
          expect(result.last, itemId, reason: reason);
        }
      },
      tags: 'glados',
    );
  });

  group('ChecklistController', () {
    group('delete', () {
      test(
        'deletes and detaches a task checklist through the repository',
        () async {
          final container = await loaded();

          final result = await notifierOf(container).delete();

          expect(result, isTrue);
          verify(
            () => mockChecklistRepository.deleteChecklist(
              checklistId: 'checklist-1',
              taskId: 'task-1',
            ),
          ).called(1);
          verifyNever(() => mockJournalRepository.deleteJournalEntity(any()));
          expect(stateOf(container), isNull);
        },
      );

      test(
        'deletes a checklist without a task through the journal repository',
        () async {
          const params = (id: 'checklist-1', taskId: null);
          final container = await loaded(params);

          final result = await notifierOf(container, params).delete();

          expect(result, isTrue);
          verify(
            () => mockJournalRepository.deleteJournalEntity('checklist-1'),
          ).called(1);
          verifyNever(
            () => mockChecklistRepository.deleteChecklist(
              checklistId: any(named: 'checklistId'),
              taskId: any(named: 'taskId'),
            ),
          );
          expect(stateOf(container, params), isNull);
        },
      );

      test('returns false and keeps the state when deletion fails', () async {
        when(
          () => mockChecklistRepository.deleteChecklist(
            checklistId: any(named: 'checklistId'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => false);
        final container = await loaded();

        final result = await notifierOf(container).delete();

        expect(result, isFalse);
        expect(stateOf(container), testChecklist);
      });

      test(
        'returns false and keeps the state when a task-less delete fails',
        () async {
          when(
            () => mockJournalRepository.deleteJournalEntity(any()),
          ).thenAnswer((_) async => false);
          const params = (id: 'checklist-1', taskId: null);
          final container = await loaded(params);

          final result = await notifierOf(container, params).delete();

          expect(result, isFalse);
          expect(stateOf(container, params), testChecklist);
        },
      );
    });

    group('updateChecklist', () {
      test('is a no-op while the provider has no value yet', () async {
        // Keep the async build pending so state.value is null when the
        // mutation fires.
        when(
          () => mockDb.journalEntityById('checklist-1'),
        ).thenAnswer((_) => Completer<JournalEntity?>().future);
        final container = makeContainer();

        await notifierOf(container).updateChecklist((c) => c);

        verifyNoChecklistWrite();
      });

      test('keeps the current state when the write fails', () async {
        when(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            change: any(named: 'change'),
          ),
        ).thenAnswer((_) async => null);
        final container = await loaded();

        await notifierOf(container).updateTitle('Never stored');

        expect(stateOf(container), testChecklist);
      });

      test(
        'publishes the checklist as stored, not as the state had it',
        () async {
          final container = await loaded();
          storeMeanwhile(const ['item-1', 'item-2', 'item-synced']);

          await notifierOf(container).updateTitle('Renamed');

          expect(stateOf(container)?.data.title, 'Renamed');
          expect(
            stateOf(container)?.data.linkedChecklistItems,
            ['item-1', 'item-2', 'item-synced'],
          );
        },
      );
    });

    group('dropChecklistItem - same checklist reordering', () {
      late ProviderContainer container;

      Future<ChecklistController> bootstrap() async {
        seed(
          makeChecklist('checklist-1', const ['item-1', 'item-2', 'item-3']),
        );
        container = await loaded();
        return notifierOf(container);
      }

      test('updateItemOrder stores the given order', () async {
        final notifier = await bootstrap();

        await notifier.updateItemOrder(const ['item-3', 'item-1', 'item-2']);

        expect(storedItems(), ['item-3', 'item-1', 'item-2']);
      });

      test(
        'updateItemOrder keeps an item stored after the screen loaded',
        () async {
          final notifier = await bootstrap();
          storeMeanwhile(const ['item-1', 'item-2', 'item-3', 'item-synced']);

          await notifier.updateItemOrder(const ['item-3', 'item-1', 'item-2']);

          expect(
            storedItems(),
            ['item-3', 'item-1', 'item-2', 'item-synced'],
          );
          expect(
            stateOf(container)?.data.linkedChecklistItems,
            ['item-3', 'item-1', 'item-2', 'item-synced'],
          );
        },
      );

      test('reorders item to target index position', () async {
        final notifier = await bootstrap();

        // Remove item-1: [item-2, item-3]; targetIndex=2 > oldIndex=0, so
        // newIndex = 2 - 1 = 1.
        await notifier.dropChecklistItem(
          {'checklistItemId': 'item-1', 'checklistId': 'checklist-1'},
          targetIndex: 2,
        );

        expect(storedItems(), ['item-2', 'item-1', 'item-3']);
      });

      test(
        'a drop reorder keeps an item that synced in after the screen loaded',
        () async {
          final notifier = await bootstrap();
          storeMeanwhile(const ['item-1', 'item-2', 'item-3', 'item-synced']);

          await notifier.dropChecklistItem(
            {'checklistItemId': 'item-1', 'checklistId': 'checklist-1'},
            targetIndex: 2,
          );

          expect(
            storedItems(),
            ['item-2', 'item-1', 'item-3', 'item-synced'],
          );
        },
      );

      test('reorders item using targetItemId (insert after)', () async {
        final notifier = await bootstrap();

        await notifier.dropChecklistItem(
          {'checklistItemId': 'item-1', 'checklistId': 'checklist-1'},
          targetItemId: 'item-2',
        );

        expect(storedItems(), ['item-2', 'item-1', 'item-3']);
      });

      test('does nothing when item not in checklist', () async {
        final notifier = await bootstrap();

        await notifier.dropChecklistItem(
          {'checklistItemId': 'non-existent', 'checklistId': 'checklist-1'},
          targetIndex: 0,
        );

        verifyNoChecklistWrite();
      });

      test(
        'appends to end when no position specified for same checklist',
        () async {
          final notifier = await bootstrap();

          await notifier.dropChecklistItem({
            'checklistItemId': 'item-1',
            'checklistId': 'checklist-1',
          });

          expect(storedItems(), ['item-2', 'item-3', 'item-1']);
        },
      );
    });

    group('dropChecklistItem - cross-checklist move', () {
      const targetParams = (id: 'target-cl', taskId: 'task-1');

      /// Serves `moveItem` as the repository does for the lists: [place]
      /// applied to the stored target list, the item removed from the stored
      /// source list. Returns the written target.
      void stubMove() =>
          when(
            () => mockChecklistRepository.moveItem(
              itemId: any(named: 'itemId'),
              fromId: any(named: 'fromId'),
              toId: any(named: 'toId'),
              taskId: any(named: 'taskId'),
              place: any(named: 'place'),
            ),
          ).thenAnswer((invocation) async {
            final args = invocation.namedArguments;
            final itemId = args[#itemId] as String;
            final place = args[#place] as ChecklistIdsChange;
            final target = stored[args[#toId] as String]!;
            final source = stored[args[#fromId] as String]!;
            stored[target.id] = target.copyWith(
              data: target.data.copyWith(
                linkedChecklistItems: place(target.data.linkedChecklistItems),
              ),
            );
            stored[source.id] = source.copyWith(
              data: source.data.copyWith(
                linkedChecklistItems: source.data.linkedChecklistItems
                    .where((id) => id != itemId)
                    .toList(),
              ),
            );
            return stored[target.id];
          });

      Future<ProviderContainer> bootstrap({
        required List<String> source,
        required List<String> target,
      }) async {
        seed(makeChecklist('source-cl', source));
        seed(makeChecklist('target-cl', target));
        stubMove();
        return loaded(targetParams);
      }

      ChecklistController targetNotifier(ProviderContainer container) =>
          notifierOf(container, targetParams);

      test(
        'moves the item as one repository move and publishes the target',
        () async {
          final container = await bootstrap(
            source: const ['item-1', 'item-2'],
            target: const [],
          );

          await targetNotifier(container).dropChecklistItem(
            {'checklistItemId': 'item-1', 'checklistId': 'source-cl'},
          );

          verify(
            () => mockChecklistRepository.moveItem(
              itemId: 'item-1',
              fromId: 'source-cl',
              toId: 'target-cl',
              taskId: 'task-1',
              place: any(named: 'place'),
            ),
          ).called(1);
          // The controller writes no list itself.
          verifyNoChecklistWrite();
          expect(storedItems('target-cl'), ['item-1']);
          expect(storedItems('source-cl'), ['item-2']);
          expect(stateOf(container, targetParams), stored['target-cl']);
        },
      );

      test('inserts at targetIndex when dropping on a row', () async {
        final container = await bootstrap(
          source: const ['dragged'],
          target: const ['a', 'b', 'c'],
        );

        // Dropping on the row at index 1 ('b') means "insert before b".
        await targetNotifier(container).dropChecklistItem(
          {'checklistItemId': 'dragged', 'checklistId': 'source-cl'},
          targetIndex: 1,
        );

        expect(storedItems('target-cl'), ['a', 'dragged', 'b', 'c']);
        expect(
          stateOf(container, targetParams)?.data.linkedChecklistItems,
          ['a', 'dragged', 'b', 'c'],
        );
      });

      test('inserts after targetItemId when only id is provided', () async {
        final container = await bootstrap(
          source: const ['dragged'],
          target: const ['a', 'b', 'c'],
        );

        await targetNotifier(container).dropChecklistItem(
          {'checklistItemId': 'dragged', 'checklistId': 'source-cl'},
          targetItemId: 'b',
        );

        expect(storedItems('target-cl'), ['a', 'b', 'dragged', 'c']);
      });

      test('appends to end when no positioning info is provided', () async {
        final container = await bootstrap(
          source: const ['dragged'],
          target: const ['a', 'b'],
        );

        await targetNotifier(container).dropChecklistItem(
          {'checklistItemId': 'dragged', 'checklistId': 'source-cl'},
        );

        expect(storedItems('target-cl'), ['a', 'b', 'dragged']);
      });

      test(
        'places the item into the stored target list, keeping an item synced '
        'in after the screen loaded',
        () async {
          final container = await bootstrap(
            source: const ['dragged'],
            target: const ['a', 'b'],
          );
          stored['target-cl'] = makeChecklist('target-cl', const [
            'a',
            'b',
            'synced',
          ]);

          await targetNotifier(container).dropChecklistItem(
            {'checklistItemId': 'dragged', 'checklistId': 'source-cl'},
            targetItemId: 'a',
          );

          expect(storedItems('target-cl'), ['a', 'dragged', 'b', 'synced']);
        },
      );

      test('keeps the target state when the move writes nothing', () async {
        final container = await bootstrap(
          source: const ['dragged'],
          target: const ['a'],
        );
        when(
          () => mockChecklistRepository.moveItem(
            itemId: any(named: 'itemId'),
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            taskId: any(named: 'taskId'),
            place: any(named: 'place'),
          ),
        ).thenAnswer((_) async => null);
        final before = stateOf(container, targetParams);

        await targetNotifier(container).dropChecklistItem(
          {'checklistItemId': 'dragged', 'checklistId': 'source-cl'},
        );

        expect(stateOf(container, targetParams), before);
        expect(before?.data.linkedChecklistItems, ['a']);
      });
    });

    group('_listen / update notifications', () {
      test(
        'refreshes state when a subscribed ID appears in update stream',
        () async {
          final container = await loaded();

          final updatedChecklist = testChecklist.copyWith(
            data: const ChecklistData(
              title: 'Updated Title',
              linkedChecklistItems: ['item-1', 'item-2', 'item-3'],
              linkedTasks: ['task-1'],
            ),
          );
          when(
            () => mockDb.journalEntityById('checklist-1'),
          ).thenAnswer((_) async => updatedChecklist);

          updateStreamController.add({'checklist-1'});

          // Drain the event queue deterministically so the stream listener's
          // async callback completes — no zero-duration Timers (fake-time
          // policy).
          await pumpEventQueue();

          expect(stateOf(container)?.data.title, 'Updated Title');
          expect(
            stateOf(container)?.data.linkedChecklistItems,
            ['item-1', 'item-2', 'item-3'],
          );
        },
      );

      test('ignores notifications for unrelated IDs', () async {
        await loaded();

        var fetchCount = 0;
        when(
          () => mockDb.journalEntityById('checklist-1'),
        ).thenAnswer((_) async {
          fetchCount++;
          return testChecklist;
        });

        updateStreamController.add({'unrelated-id'});
        await pumpEventQueue();

        expect(fetchCount, isZero);
      });
    });

    group('updateTitle', () {
      test('stores the new title and publishes it', () async {
        final container = await loaded();

        await notifierOf(container).updateTitle('New Title');

        expect(stored['checklist-1']!.data.title, 'New Title');
        expect(stateOf(container)?.data.title, 'New Title');
      });

      test('stores the empty string when title is null', () async {
        final container = await loaded();

        await notifierOf(container).updateTitle(null);

        expect(stored['checklist-1']!.data.title, '');
      });
    });

    group('item deletion (swipe, undo window)', () {
      const undoWindow = Duration(seconds: 5);

      test(
        'beginItemDeletion records the deletion for this checklist and '
        'publishes the list as stored without the item',
        () async {
          when(
            () => mockChecklistRepository.beginItemDeletion(
              itemId: any(named: 'itemId'),
              checklistId: any(named: 'checklistId'),
              undoWindow: any(named: 'undoWindow'),
            ),
          ).thenAnswer((_) async {
            storeMeanwhile(const ['item-2', 'item-synced']);
            return 'deletion-key';
          });
          final container = await loaded();

          final key = await notifierOf(
            container,
          ).beginItemDeletion('item-1', undoWindow: undoWindow);

          expect(key, 'deletion-key');
          // The repository times the window, not the caller.
          verify(
            () => mockChecklistRepository.beginItemDeletion(
              itemId: 'item-1',
              checklistId: 'checklist-1',
              undoWindow: undoWindow,
            ),
          ).called(1);
          verifyNever(
            () => mockChecklistRepository.completeItemDeletion(
              key: any(named: 'key'),
              itemId: any(named: 'itemId'),
            ),
          );
          verifyNever(() => mockJournalRepository.deleteJournalEntity(any()));
          // The re-read row, including an item synced in meanwhile.
          expect(
            stateOf(container)?.data.linkedChecklistItems,
            ['item-2', 'item-synced'],
          );
        },
      );

      test(
        'beginItemDeletion returns null when the deletion was not recorded',
        () async {
          when(
            () => mockChecklistRepository.beginItemDeletion(
              itemId: any(named: 'itemId'),
              checklistId: any(named: 'checklistId'),
              undoWindow: any(named: 'undoWindow'),
            ),
          ).thenAnswer((_) async => null);
          final container = await loaded();

          final key = await notifierOf(
            container,
          ).beginItemDeletion('item-1', undoWindow: undoWindow);

          expect(key, isNull);
          expect(
            stateOf(container)?.data.linkedChecklistItems,
            ['item-1', 'item-2'],
          );
        },
      );

      test(
        'undoItemDeletion relists the item on this checklist and publishes '
        'the written checklist',
        () async {
          final relisted = makeChecklist(
            'checklist-1',
            const ['item-1', 'item-2', 'item-synced'],
          );
          when(
            () => mockChecklistRepository.undoItemDeletion(
              key: any(named: 'key'),
              itemId: any(named: 'itemId'),
              checklistId: any(named: 'checklistId'),
            ),
          ).thenAnswer((_) async => relisted);
          final container = await loaded();

          await notifierOf(container).undoItemDeletion(
            key: 'deletion-key',
            checklistItemId: 'item-1',
          );

          verify(
            () => mockChecklistRepository.undoItemDeletion(
              key: 'deletion-key',
              itemId: 'item-1',
              checklistId: 'checklist-1',
            ),
          ).called(1);
          expect(stateOf(container), relisted);
        },
      );

      test(
        'undoItemDeletion keeps the state when nothing was written',
        () async {
          when(
            () => mockChecklistRepository.undoItemDeletion(
              key: any(named: 'key'),
              itemId: any(named: 'itemId'),
              checklistId: any(named: 'checklistId'),
            ),
          ).thenAnswer((_) async => null);
          final container = await loaded();

          await notifierOf(container).undoItemDeletion(
            key: 'deletion-key',
            checklistItemId: 'item-1',
          );

          expect(stateOf(container), testChecklist);
        },
      );
    });

    group('createChecklistItem', () {
      /// Serves `addItemToChecklist` as the repository does: the item is
      /// created and listed on the stored checklist.
      void stubAdd(ChecklistItem? created) =>
          when(
            () => mockChecklistRepository.addItemToChecklist(
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              checklistId: any(named: 'checklistId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((invocation) async {
            if (created != null) {
              final checklistId =
                  invocation.namedArguments[#checklistId] as String;
              final current = stored[checklistId]!;
              stored[checklistId] = current.copyWith(
                data: current.data.copyWith(
                  linkedChecklistItems: [
                    ...current.data.linkedChecklistItems,
                    created.id,
                  ],
                ),
              );
            }
            return created;
          });

      test('adds the item via the repository and returns its id', () async {
        stubAdd(makeItem('new-item-1'));
        final container = await loaded();

        final createdId = await notifierOf(container).createChecklistItem(
          'New Item',
          isChecked: false,
          categoryId: null,
        );

        expect(createdId, 'new-item-1');
        verify(
          () => mockChecklistRepository.addItemToChecklist(
            title: 'New Item',
            isChecked: false,
            checklistId: 'checklist-1',
            categoryId: null,
          ),
        ).called(1);
        // The repository lists the item; the controller writes no list.
        verifyNoChecklistWrite();
        expect(
          stateOf(container)?.data.linkedChecklistItems,
          ['item-1', 'item-2', 'new-item-1'],
        );
      });

      test(
        'publishes the checklist re-read as stored, not the stale state',
        () async {
          stubAdd(makeItem('new-item-1'));
          final container = await loaded();
          storeMeanwhile(const ['item-1', 'item-2', 'item-synced']);

          await notifierOf(container).createChecklistItem(
            'New Item',
            isChecked: false,
            categoryId: null,
          );

          expect(
            stateOf(container)?.data.linkedChecklistItems,
            ['item-1', 'item-2', 'item-synced', 'new-item-1'],
          );
        },
      );

      test(
        'returns null and keeps the state when the item was not added',
        () async {
          stubAdd(null);
          final container = await loaded();

          final createdId = await notifierOf(container).createChecklistItem(
            'New Item',
            isChecked: true,
            categoryId: 'cat-1',
          );

          expect(createdId, isNull);
          expect(stateOf(container), testChecklist);
        },
      );

      test('returns null when title is null', () async {
        final container = await loaded();

        final createdId = await notifierOf(container).createChecklistItem(
          null,
          isChecked: false,
          categoryId: null,
        );

        expect(createdId, isNull);
        verifyNever(
          () => mockChecklistRepository.addItemToChecklist(
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            checklistId: any(named: 'checklistId'),
            categoryId: any(named: 'categoryId'),
          ),
        );
      });

      group('dropChecklistNewItem', () {
        test('creates the dragged item and lists it', () async {
          stubAdd(makeItem('dropped-item-1', title: 'Dropped Item'));
          final container = await loaded();

          await notifierOf(container).dropChecklistNewItem(
            {'checklistItemTitle': 'Dropped Item', 'checklistItemStatus': true},
            categoryId: 'cat-1',
          );

          verify(
            () => mockChecklistRepository.addItemToChecklist(
              title: 'Dropped Item',
              isChecked: true,
              checklistId: 'checklist-1',
              categoryId: 'cat-1',
            ),
          ).called(1);
          expect(
            stateOf(container)?.data.linkedChecklistItems,
            ['item-1', 'item-2', 'dropped-item-1'],
          );
        });

        test(
          'does nothing when localData map has no checklistItemTitle',
          () async {
            final container = await loaded();

            await notifierOf(
              container,
            ).dropChecklistNewItem({'someOtherKey': 'value'});

            verifyNever(
              () => mockChecklistRepository.addItemToChecklist(
                title: any(named: 'title'),
                isChecked: any(named: 'isChecked'),
                checklistId: any(named: 'checklistId'),
                categoryId: any(named: 'categoryId'),
              ),
            );
            expect(stateOf(container), testChecklist);
          },
        );

        test(
          'dropChecklistItem delegates to dropChecklistNewItem for new items',
          () async {
            stubAdd(makeItem('new-via-drop'));
            final container = await loaded();

            await notifierOf(container).dropChecklistItem(
              {
                'checklistItemTitle': 'Dropped via route',
                'checklistItemStatus': true,
              },
              categoryId: 'cat-1',
            );

            verify(
              () => mockChecklistRepository.addItemToChecklist(
                title: 'Dropped via route',
                isChecked: true,
                checklistId: 'checklist-1',
                categoryId: 'cat-1',
              ),
            ).called(1);
            expect(storedItems(), ['item-1', 'item-2', 'new-via-drop']);
          },
        );
      });
    });
  });
}
