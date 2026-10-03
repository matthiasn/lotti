import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/signals/health_signal_refresh_service.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import 'actual_time_blocks_provider_test_helpers.dart';

void main() {
  group('dailyOsActualTimeUpdateProvider', () {
    test('actualTimelineUpdateBatches drops empty batches', () async {
      final batches = await actualTimelineUpdateBatches(
        Stream.fromIterable([
          <String>{},
          {'entry-1'},
          <String>{},
          {'entry-2', 'entry-3'},
        ]),
      ).toList();

      expect(batches, [
        {'entry-1'},
        {'entry-2', 'entry-3'},
      ]);
    });

    test(
      'bridges the registered notification stream, empties dropped',
      () async {
        final notifications = MockUpdateNotifications();
        when(() => notifications.updateStream).thenAnswer(
          (_) => Stream.fromIterable([
            <String>{},
            {'entry-1'},
          ]),
        );
        getIt.registerSingleton<UpdateNotifications>(notifications);
        addTearDown(getIt.reset);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        // autoDispose: without a live listener the provider is torn down
        // between the read and the first emission.
        final subscription = container.listen(
          dailyOsActualTimeUpdateProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        final first = await container.read(
          dailyOsActualTimeUpdateProvider.future,
        );

        expect(first, {'entry-1'});
      },
    );
  });

  group('dailyOsActualTimeBlocksProvider', () {
    final day = DateTime(2026, 5, 27);
    late MockJournalDb db;

    setUp(() {
      db = MockJournalDb();
      final walk = hWorkout(id: 'walk', day: day, startHour: 7);
      when(
        () => db.sortedCalendarEntries(
          rangeStart: day,
          rangeEnd: day.add(const Duration(days: 1)),
        ),
      ).thenAnswer((_) async => [walk]);
      when(
        () => db.basicLinksForEntryIds({walk.meta.id}),
      ).thenAnswer((_) async => const []);
    });

    // A check-in's person is its relationshipId. The stored RelationshipLink
    // is not a BasicLink, and a check-in can outlive a failed link write, so
    // the block names the person with no stored link at all.
    test(
      'a check-in is titled by its person with no stored link at all',
      () async {
        final person = testRelationship;
        final call = CheckInEntry(
          meta: Metadata(
            id: 'call',
            createdAt: day,
            updatedAt: day,
            dateFrom: day.add(const Duration(hours: 13)),
            dateTo: day.add(const Duration(hours: 14, minutes: 15)),
          ),
          data: CheckInData(
            relationshipId: person.meta.id,
            interactionType: CheckInInteractionType.call,
          ),
          entryText: const EntryText(plainText: 'Talked about the move.'),
        );
        when(
          () => db.sortedCalendarEntries(
            rangeStart: day,
            rangeEnd: day.add(const Duration(days: 1)),
          ),
        ).thenAnswer((_) async => [call]);
        when(
          () => db.basicLinksForEntryIds({call.meta.id}),
        ).thenAnswer((_) async => const []);
        when(
          () => db.getJournalEntitiesForIdsUnordered({person.meta.id}),
        ).thenAnswer((_) async => [person]);
        final container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(db),
            healthSignalRefreshServiceProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        final blocks = await readActualBlocks(container, day);

        expect(blocks.single.title, 'Anna');
        expect(
          blocks.single.end.difference(blocks.single.start),
          const Duration(hours: 1, minutes: 15),
        );
      },
    );

    // Workouts reach the journal only through the health import, and this
    // lane used to wait for a dashboard to ask for one.
    test('nudges the workout importer and projects the day', () async {
      final healthImport = MockHealthImport();
      when(
        healthImport.getWorkoutsHealthDataDelta,
      ).thenAnswer((_) async => const HealthImportResult.imported(0));
      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(db),
          healthSignalRefreshServiceProvider.overrideWithValue(
            HealthSignalRefreshService(healthImport),
          ),
        ],
      );
      addTearDown(container.dispose);

      final blocks = await readActualBlocks(container, day);

      expect(blocks.single.title, 'Walking');
      expect(blocks.single.id, 'actual:walk');
      verify(healthImport.getWorkoutsHealthDataDelta).called(1);
    });

    test(
      'projects the day without an importer (desktop, demo worlds)',
      () async {
        final container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(db),
            healthSignalRefreshServiceProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        final blocks = await readActualBlocks(container, day);

        expect(blocks.single.title, 'Walking');
      },
    );

    test(
      'resolves linked-from entities through the database and categories '
      'through the cache',
      () async {
        final task = hTask(
          id: 'task-1',
          title: 'Write release notes',
          categoryId: 'cat-work',
          day: day,
        );
        final entry = hEntry(
          id: 'entry-1',
          day: day,
          startHour: 9,
          endHour: 10,
        );
        final link = hLink(
          'l1',
          from: task.meta.id,
          to: entry.meta.id,
          day: day,
        );
        when(
          () => db.sortedCalendarEntries(
            rangeStart: day,
            rangeEnd: day.add(const Duration(days: 1)),
          ),
        ).thenAnswer((_) async => [entry]);
        when(
          () => db.basicLinksForEntryIds({entry.meta.id}),
        ).thenAnswer((_) async => [link]);
        when(
          () => db.getJournalEntitiesForIdsUnordered({task.meta.id}),
        ).thenAnswer((_) async => [task]);
        final cache = MockEntitiesCacheService();
        when(() => cache.getCategoryById('cat-work')).thenReturn(
          hCategory(id: 'cat-work', name: 'Work', color: '#5ED4B7'),
        );
        getIt.registerSingleton<EntitiesCacheService>(cache);
        addTearDown(getIt.reset);
        final container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(db),
            healthSignalRefreshServiceProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        final blocks = await readActualBlocks(container, day);

        expect(blocks.single.title, 'Write release notes');
        expect(blocks.single.taskId, 'task-1');
        expect(blocks.single.category.name, 'Work');
      },
    );

    group('the Events flag', () {
      late JournalEvent dinner;

      setUp(() {
        final walk = hWorkout(id: 'walk', day: day, startHour: 7);
        dinner = hEvent(id: 'dinner', day: day, startHour: 18, endHour: 24);
        when(
          () => db.sortedCalendarEntries(
            rangeStart: day,
            rangeEnd: day.add(const Duration(days: 1)),
          ),
        ).thenAnswer((_) async => [walk, dinner]);
        when(
          () => db.basicLinksForEntryIds({walk.meta.id, dinner.meta.id}),
        ).thenAnswer((_) async => const []);
      });

      ProviderContainer container() {
        final container = ProviderContainer(
          overrides: [
            journalDbProvider.overrideWithValue(db),
            healthSignalRefreshServiceProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      test('on: the event is on the lane', () async {
        when(
          () => db.watchConfigFlag(enableEventsFlag),
        ).thenAnswer((_) => Stream.value(true));

        final blocks = await readActualBlocks(container(), day);

        expect(blocks.map((block) => block.title), [
          'Walking',
          'Dinner with a friend',
        ]);
      });

      test('off: the event is hidden, like everywhere else', () async {
        when(
          () => db.watchConfigFlag(enableEventsFlag),
        ).thenAnswer((_) => Stream.value(false));

        final blocks = await readActualBlocks(container(), day);

        expect(blocks.map((block) => block.title), ['Walking']);
      });

      test('flipping it repaints the lane without a restart', () async {
        final flag = StreamController<bool>();
        addTearDown(flag.close);
        when(
          () => db.watchConfigFlag(enableEventsFlag),
        ).thenAnswer((_) => flag.stream);
        final scope = container();
        final painted = <List<String>>[];
        final subscription = scope.listen(
          dailyOsActualTimeBlocksProvider(day),
          (_, next) {
            // Only settled paints: a reload first re-emits the previous
            // value as a loading state, which is not a repaint of the lane.
            if (next is AsyncData<List<TimeBlock>>) {
              painted.add(next.value.map((block) => block.title).toList());
            }
          },
        );
        addTearDown(subscription.close);

        flag.add(true);
        await scope.read(dailyOsActualTimeBlocksProvider(day).future);
        flag.add(false);
        await pumpEventQueue();

        expect(painted, [
          ['Walking', 'Dinner with a friend'],
          ['Walking'],
        ]);
      });
    });

    test('a failing importer does not take the lane down', () async {
      final healthImport = MockHealthImport();
      when(
        healthImport.getWorkoutsHealthDataDelta,
      ).thenThrow(StateError('health store unavailable'));
      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(db),
          healthSignalRefreshServiceProvider.overrideWithValue(
            HealthSignalRefreshService(healthImport),
          ),
        ],
      );
      addTearDown(container.dispose);

      final blocks = await readActualBlocks(container, day);

      expect(blocks.single.title, 'Walking');
    });
  });
}
