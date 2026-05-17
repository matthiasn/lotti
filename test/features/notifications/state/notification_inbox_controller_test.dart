import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/notifications/state/notification_inbox_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

import '../../../widget_test_utils.dart';

// All `scheduledFor` timestamps in these tests sit far enough in the past or
// future of any plausible wall-clock that the provider's `DateTime.now()`
// dueNow/upcoming split is deterministic across machines.
final _farPast = DateTime.utc(2000);
final _farFuture = DateTime.utc(2099);

void main() {
  late NotificationsDb db;
  late UpdateNotifications updateNotifications;

  setUp(() async {
    db = NotificationsDb(inMemoryDatabase: true, background: false);
    updateNotifications = UpdateNotifications();
    // setUpTestGetIt registers a stubbed MockUpdateNotifications whose
    // updateStream is Stream.empty() — useless here because the providers
    // rely on a live broadcast stream. Drop in a real instance (and the
    // in-memory NotificationsDb) inside the helper's additionalSetup hook
    // instead of hand-rolling reset / re-register cycles per test.
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(updateNotifications)
          ..registerSingleton<NotificationsDb>(db);
      },
    );
  });

  tearDown(() async {
    await db.close();
    await updateNotifications.dispose();
    await tearDownTestGetIt();
  });

  test('unseen count reflects rows below the current scheduled_for', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await db.upsertNotification(
      _notification(id: 'past', scheduledFor: _farPast),
    );
    await db.upsertNotification(
      _notification(id: 'future', scheduledFor: _farFuture),
    );

    final count = await container.read(unseenNotificationCountProvider.future);
    expect(count, 1);
  });

  test('inbox list concatenates due then upcoming rows', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await db.upsertNotification(
      _notification(id: 'due-row', scheduledFor: _farPast),
    );
    await db.upsertNotification(
      _notification(id: 'upcoming-row', scheduledFor: _farFuture),
    );

    final entries = await container.read(inboxNotificationsProvider.future);

    expect(entries.map((e) => e.id).toList(), ['due-row', 'upcoming-row']);
  });

  testWidgets(
    'inboxNotification on UpdateNotifications.updateStream triggers refetch',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seed with no rows — initial count is 0.
      final initial = await container.read(
        unseenNotificationCountProvider.future,
      );
      expect(initial, 0);

      // Insert a due row and emit the inbox notification id.
      await db.upsertNotification(
        _notification(id: 'late-arrival', scheduledFor: _farPast),
      );
      updateNotifications.notify({inboxNotification});

      // notify() debounces 100 ms before emitting on the stream; the listener
      // then awaits a fresh DB read. Pump microtasks/timers a few times so
      // every async hop has a chance to complete without sleeping wall-clock.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        container.read(unseenNotificationCountProvider).value,
        1,
      );
    },
  );

  testWidgets(
    'inboxNotification refreshes the inbox list provider',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final firstSnapshot = await container.read(
        inboxNotificationsProvider.future,
      );
      expect(firstSnapshot, isEmpty);

      await db.upsertNotification(
        _notification(id: 'late-list', scheduledFor: _farPast),
      );
      updateNotifications.notify({inboxNotification});

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final after = container.read(inboxNotificationsProvider).value;
      expect(after?.map((e) => e.id).toList(), ['late-list']);
    },
  );

  testWidgets(
    'unrelated updateStream events do not trigger a refetch',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container.read(
        unseenNotificationCountProvider.future,
      );
      expect(initial, 0);

      await db.upsertNotification(
        _notification(id: 'silent', scheduledFor: _farPast),
      );
      updateNotifications.notify({'SOMETHING_ELSE'});
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Provider should still report 0 because no inboxNotification fired.
      expect(container.read(unseenNotificationCountProvider).value, 0);
    },
  );

  testWidgets(
    '_refresh surfaces fetch failures as AsyncError on the inbox list',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(inboxNotificationsProvider.future);

      // Force fetch to throw on the next call.
      await db.close();
      updateNotifications.notify({inboxNotification});

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final state = container.read(inboxNotificationsProvider);
      expect(state, isA<AsyncError<List<NotificationEntity>>>());
    },
  );

  testWidgets(
    '_refresh surfaces fetch failures as AsyncError on the unseen count',
    (tester) async {
      // Drive the controller directly via a ProviderContainer so we can swap
      // the db registration mid-flight: build() succeeds with the real DB,
      // then we close the DB to make the next fetch fail.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(unseenNotificationCountProvider.future);

      // Force fetch to throw on the next call.
      await db.close();
      updateNotifications.notify({inboxNotification});

      // Let the 100 ms notify-debounce fire, then let _refresh complete.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final state = container.read(unseenNotificationCountProvider);
      expect(state, isA<AsyncError<int>>());
    },
  );
}

NotificationEntity _notification({
  required String id,
  required DateTime scheduledFor,
}) {
  final createdAt = DateTime.utc(2026, 5, 17);
  return NotificationEntity.taskSuggestion(
    meta: NotificationMeta(
      id: id,
      createdAt: createdAt,
      updatedAt: createdAt,
      scheduledFor: scheduledFor,
      vectorClock: const VectorClock({'host-A': 1}),
      originatingHostId: 'host-A',
    ),
    linkedTaskId: 'task-$id',
    suggestionCount: 1,
    title: 'Title $id',
    body: 'Body $id',
  );
}
