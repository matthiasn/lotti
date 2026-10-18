import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/logic/goal_charter.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_charter_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  JournalEntry entry(String id, String text, {int day = 1}) =>
      testTextEntryNoGeo.copyWith(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: id,
          dateFrom: DateTime(2026, 8, day),
        ),
        entryText: EntryText(plainText: text),
      );

  group('goalCharterEntriesProvider', () {
    late MockGoalRepository repository;
    late MockUpdateNotifications notifications;
    late StreamController<Set<String>> updates;
    late ProviderContainer container;
    late List<JournalEntry> stored;

    setUp(() {
      repository = MockGoalRepository();
      notifications = MockUpdateNotifications();
      updates = StreamController<Set<String>>.broadcast();
      stored = [entry('purpose', 'This goal is my journal.')];
      when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
      when(() => repository.goalIdForAgent('agent-1')).thenReturn('goal-1');
      when(
        () => repository.charterEntries('agent-1'),
      ).thenAnswer((_) async => stored);
      container = ProviderContainer(
        overrides: [
          goalRepositoryProvider.overrideWithValue(repository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await updates.close();
    });

    Future<List<JournalEntry>> read() =>
        container.read(goalCharterEntriesProvider('agent-1').future);

    test("reads the goal's charter", () async {
      final subscription = container.listen(
        goalCharterEntriesProvider('agent-1'),
        (_, _) {},
      );
      addTearDown(subscription.close);

      expect((await read()).map((e) => e.meta.id), ['purpose']);
    });

    test('re-reads when the goal is notified, keeping the last charter while '
        'it does', () async {
      final values = <AsyncValue<List<JournalEntry>>>[];
      final subscription = container.listen(
        goalCharterEntriesProvider('agent-1'),
        (_, next) => values.add(next),
      );
      addTearDown(subscription.close);
      await read();

      stored = [
        ...stored,
        entry('style', 'Ask me one guided question each morning.', day: 2),
      ];
      updates.add({'goal-1'});
      await pumpEventQueue();

      expect(
        (await read()).map((e) => e.meta.id),
        ['purpose', 'style'],
      );
      // The reload never surfaced an empty or valueless state: the card
      // keeps showing the old charter until the new one lands.
      expect(values.every((value) => value.hasValue), isTrue);
      verify(() => repository.charterEntries('agent-1')).called(2);
    });

    test('a private entry being hidden or shown re-reads it', () async {
      final subscription = container.listen(
        goalCharterEntriesProvider('agent-1'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await read();

      updates.add({privateToggleNotification});
      await pumpEventQueue();
      await read();

      verify(() => repository.charterEntries('agent-1')).called(2);
    });

    test('an unrelated notification reads nothing', () async {
      final subscription = container.listen(
        goalCharterEntriesProvider('agent-1'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await read();

      updates.add({'another-goal'});
      await pumpEventQueue();
      await read();

      verify(() => repository.charterEntries('agent-1')).called(1);
    });

    test('without a journal stack there is no charter', () async {
      final bare = ProviderContainer(
        overrides: [
          goalRepositoryProvider.overrideWithValue(null),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(bare.dispose);

      expect(
        await bare.read(goalCharterEntriesProvider('agent-1').future),
        isEmpty,
      );
    });
  });

  group('goalCharterFitsBudget', () {
    test("a charter within one wake's budget fits", () {
      expect(
        goalCharterFitsBudget([entry('purpose', 'This goal is my journal.')]),
        isTrue,
      );
    });

    test('a charter the wake would cut does not', () {
      final long = List.filled(goalCharterTokenBudget, 'krill').join(' ');
      expect(
        goalCharterFitsBudget([
          entry('purpose', 'This goal is my journal.'),
          entry('long', long, day: 2),
        ]),
        isFalse,
      );
      // One entry larger than the whole budget is cut, which is also not
      // reading all of it.
      expect(goalCharterFitsBudget([entry('long', long)]), isFalse);
    });
  });
}
