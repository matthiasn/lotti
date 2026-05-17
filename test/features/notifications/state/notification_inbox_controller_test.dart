import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/notifications/state/notification_inbox_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

void main() {
  late NotificationsDb db;
  late UpdateNotifications updateNotifications;

  setUp(() {
    db = NotificationsDb(inMemoryDatabase: true, background: false);
    updateNotifications = UpdateNotifications();
    if (getIt.isRegistered<NotificationsDb>()) {
      getIt.unregister<NotificationsDb>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
    getIt
      ..registerSingleton<NotificationsDb>(db)
      ..registerSingleton<UpdateNotifications>(updateNotifications);
  });

  tearDown(() async {
    await db.close();
    await updateNotifications.dispose();
    if (getIt.isRegistered<NotificationsDb>()) {
      getIt.unregister<NotificationsDb>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
  });

  test('unseen count reflects rows below the current scheduled_for', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await db.upsertNotification(
      _notification(
        id: 'past',
        scheduledFor: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    );
    await db.upsertNotification(
      _notification(
        id: 'future',
        scheduledFor: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    final count = await container.read(unseenNotificationCountProvider.future);
    expect(count, 1);
  });

  test('inbox list concatenates due then upcoming rows', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pastTime = DateTime.now().subtract(const Duration(minutes: 5));
    final futureTime = DateTime.now().add(const Duration(hours: 1));

    await db.upsertNotification(
      _notification(id: 'due-row', scheduledFor: pastTime),
    );
    await db.upsertNotification(
      _notification(id: 'upcoming-row', scheduledFor: futureTime),
    );

    final entries = await container.read(inboxNotificationsProvider.future);

    expect(entries.map((e) => e.id).toList(), ['due-row', 'upcoming-row']);
  });

  test(
    'inboxNotification on UpdateNotifications.updateStream triggers refetch',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seed with no rows — initial count is 0.
      var initial = await container.read(
        unseenNotificationCountProvider.future,
      );
      expect(initial, 0);

      // Insert a due row and emit the inbox notification id.
      await db.upsertNotification(
        _notification(
          id: 'late-arrival',
          scheduledFor: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      updateNotifications.notify({inboxNotification});

      // The notify() helper debounces emission by 100 ms before pushing.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // Read again — refetch should have run and bumped the count.
      initial = container.read(unseenNotificationCountProvider).value ?? -1;
      expect(initial, 1);
    },
  );

  test(
    'inboxNotification refreshes the inbox list provider',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final firstSnapshot = await container.read(
        inboxNotificationsProvider.future,
      );
      expect(firstSnapshot, isEmpty);

      await db.upsertNotification(
        _notification(
          id: 'late-list',
          scheduledFor: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      );
      updateNotifications.notify({inboxNotification});
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final after = container.read(inboxNotificationsProvider).value;
      expect(after?.map((e) => e.id).toList(), ['late-list']);
    },
  );

  test(
    'unrelated updateStream events do not trigger a refetch',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container.read(
        unseenNotificationCountProvider.future,
      );
      expect(initial, 0);

      await db.upsertNotification(
        _notification(
          id: 'silent',
          scheduledFor: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      updateNotifications.notify({'SOMETHING_ELSE'});
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Provider should still report 0 because no inboxNotification fired.
      expect(container.read(unseenNotificationCountProvider).value, 0);
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
