import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/notifications/model/notification_kind_flags.dart';
import 'package:lotti/features/notifications/scheduler/notification_scheduler.dart';
import 'package:lotti/features/notifications/scheduler/notification_startup_reconcile.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_collaborator_base.dart';
import 'package:lotti/logic/persistence_logic.dart' show PersistenceLogic;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/consts.dart';

/// Entity/dashboard definition and config-flag operations of
/// [PersistenceLogic].
class PersistenceDefinitionOps extends PersistenceCollaboratorBase {
  PersistenceDefinitionOps(super.logic);

  Future<int> upsertEntityDefinitionImpl(
    EntityDefinition definition,
  ) async {
    final previousMeasurable = definition is MeasurableDataType
        ? await journalDb.getMeasurableDataTypeById(definition.id)
        : null;
    final written = await _writeLocalEdit(
      definition,
      journalDb.upsertEntityDefinition,
    );
    if (written == null) return 0;
    final (entityDefinition, linesAffected) = written;
    final typeNotification = switch (entityDefinition) {
      CategoryDefinition() => categoriesNotification,
      HabitDefinition() => habitsNotification,
      DashboardDefinition() => dashboardsNotification,
      MeasurableDataType() => measurablesNotification,
      LabelDefinition() => labelsNotification,
    };
    updateNotifications.notify({entityDefinition.id, typeNotification});
    if (entityDefinition is MeasurableDataType &&
        measurementDefinitionAffectsFts(
          previousMeasurable,
          entityDefinition,
        )) {
      await _reindexMeasurements(entityDefinition);
    }
    await outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: entityDefinition,
        status: SyncEntryStatus.update,
      ),
    );
    return linesAffected;
  }

  /// Writes a local definition edit so that it applies and wins on sync.
  ///
  /// `JournalDb` refuses a definition older than the stored one — the guard
  /// that keeps a late sync arrival from overwriting a newer edit. A local
  /// edit trips the same guard when a sync landed while the editor was open
  /// and the caller did not refresh `updatedAt` (deletes from the settings
  /// pages, for one). A user's action must still apply, so the edit is
  /// rebuilt from the stored stamp: its timestamp goes strictly above the
  /// stored one — even when the peer's clock runs ahead of ours — and it
  /// carries the stored vector clock, so an ordered clock cannot outrank it
  /// (equal clocks defer to `updatedAt`). That copy applies here and wins on
  /// every peer holding the same stored version.
  ///
  /// Returns the definition that was actually stored with the write's row
  /// count, or null when even the rebuilt copy was refused — then nothing
  /// was saved, and the caller must neither announce nor sync it.
  Future<(EntityDefinition, int)?> _writeLocalEdit(
    EntityDefinition definition,
    Future<int> Function(EntityDefinition definition) write,
  ) async {
    final linesAffected = await write(definition);
    if (linesAffected != 0) {
      return (definition, linesAffected);
    }

    final stored = await journalDb.definitionStamp(definition);
    final now = clock.now();
    final floor = stored?.updatedAt;
    final restamped = definition.copyWith(
      updatedAt: floor == null || now.isAfter(floor)
          ? now
          : floor.add(const Duration(milliseconds: 1)),
      vectorClock: stored?.vectorClock ?? definition.vectorClock,
    );
    final restampedLines = await write(restamped);
    if (restampedLines == 0) {
      loggingService.error(
        LogDomain.persistence,
        StateError(
          'Local definition edit ${definition.id} refused twice; not saved',
        ),
        subDomain: 'upsertEntityDefinition.restamp',
      );
      return null;
    }
    loggingService.log(
      LogDomain.persistence,
      'Re-stamped stale local definition edit ${definition.id}',
      subDomain: 'upsertEntityDefinition.restamp',
    );
    return (restamped, restampedLines);
  }

  Future<void> _reindexMeasurements(MeasurableDataType dataType) async {
    try {
      final entries = await journalDb.getMeasurementsByTypeIncludingPrivate(
        type: dataType.id,
        rangeStart: DateTime(1),
        rangeEnd: DateTime(9999, 12, 31, 23, 59, 59, 999),
      );
      await getIt<Fts5Db>().reindexMeasurements(dataType, entries);
    } catch (exception, stackTrace) {
      // FTS is derived and can be rebuilt from the journal. A failed reindex
      // must not turn an already-persisted definition edit into a failed save
      // or prevent it from syncing.
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'upsertEntityDefinition.reindexMeasurements',
      );
    }
  }

  Future<int> upsertDashboardDefinitionImpl(
    DashboardDefinition definition,
  ) async {
    final written = await _writeLocalEdit(
      definition,
      (d) => journalDb.upsertDashboardDefinition(d as DashboardDefinition),
    );
    if (written == null) return 0;
    final (dashboard, linesAffected) = written;
    updateNotifications.notify({dashboard.id, dashboardsNotification});
    await outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: dashboard,
        status: SyncEntryStatus.update,
      ),
    );

    if (dashboard.deletedAt != null) {
      await getIt<NotificationService>().cancelNotification(
        dashboard.id.hashCode,
      );
    }

    return linesAffected;
  }

  Future<void> setConfigFlagImpl(ConfigFlag configFlag) async {
    final previous = await journalDb.getConfigFlagByName(configFlag.name);
    await journalDb.upsertConfigFlag(configFlag);
    final changed = previous?.status != configFlag.status;
    if (changed) {
      await outboxService.enqueueMessage(
        SyncMessage.configFlag(
          name: configFlag.name,
          description: configFlag.description,
          status: configFlag.status,
        ),
      );
    }
    if (configFlag.name == 'private') {
      updateNotifications.notify({privateToggleNotification});
    }
    if (changed) {
      await _applyNotificationPreference(configFlag);
    }
  }

  /// Makes a notification preference take effect the moment it is toggled,
  /// rather than at the next journal write or the next app start.
  ///
  /// Every step is best-effort: the user asked to change a setting and that
  /// write has already succeeded, so a platform call that fails is logged and
  /// never turns into a setting reported as unsaved. Flags that are not a
  /// notification preference do nothing here.
  Future<void> _applyNotificationPreference(ConfigFlag flag) async {
    switch (flag.name) {
      case enableNotificationsFlag:
        if (flag.status) {
          // Turning on is where the permission prompt surfaces — the moment
          // the user asked for it — so the badge goes first. Rows written
          // while the flag was off carry no OS alarm (the scheduler's
          // platform calls are gated on the flag, and the repository's
          // idempotent creates never re-schedule an existing row), so
          // without the reconcile only the next app start would arm them.
          // Habit reminders have no row, so they are re-armed by hand.
          await _refreshBadge();
          await _reconcileRows();
          await _rearmHabitReminders();
        } else {
          // Alarms armed weeks ahead would still fire; drop them all, then
          // take the count off the icon. The zero-badge post has to come
          // after the sweep, or it would be swept too.
          await _cancelAllAlarms();
          await _refreshBadge();
        }
      case notifyHabitRemindersFlag:
        if (flag.status) {
          await _rearmHabitReminders();
        } else {
          await _cancelHabitReminders();
        }
      case showTaskBadgeFlag:
        await _refreshBadge();
      default:
        if (notificationRowKindFlags.contains(flag.name)) {
          // Re-arms the rows of a kind switched on and cancels the alarms of
          // one switched off — `schedule` decides per row.
          await _reconcileRows();
        }
    }
  }

  Future<void> _reconcileRows() => reconcileScheduledNotifications(
    scheduler: getIt<NotificationScheduler>(),
    logger: getIt<DomainLogger>(),
  );

  /// `updateBadge` is the only thing that reconciles the icon with the flags,
  /// and nothing else calls it outside entry creation — so without this,
  /// switching the badge or notifications off left the task count sitting on
  /// the icon until the user happened to write something.
  Future<void> _refreshBadge() =>
      _bestEffort('badge', () => getIt<NotificationService>().updateBadge());

  Future<void> _cancelAllAlarms() => _bestEffort(
    'cancelAll',
    () => getIt<NotificationService>().cancelAllNotifications(),
  );

  /// Arms the next reminder of every active habit that has one. A habit
  /// already completed today gets today's reminder once more — the
  /// completion path is what skips to tomorrow, and it will again at the
  /// next completion.
  Future<void> _rearmHabitReminders() =>
      _bestEffort('habitReminders', () async {
        final notificationService = getIt<NotificationService>();
        for (final habit in await journalDb.getAllHabitDefinitions()) {
          if (habit.active) {
            await notificationService.scheduleHabitNotification(habit);
          }
        }
      });

  Future<void> _cancelHabitReminders() =>
      _bestEffort('habitReminders', () async {
        final notificationService = getIt<NotificationService>();
        for (final habit in await journalDb.getAllHabitDefinitions()) {
          await notificationService.cancelNotification(habit.id.hashCode);
        }
      });

  Future<void> _bestEffort(String step, Future<void> Function() body) async {
    try {
      await body();
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.notifications,
        exception,
        stackTrace: stackTrace,
        subDomain: 'setConfigFlag.$step',
      );
    }
  }

  Future<int> deleteDashboardDefinitionImpl(
    DashboardDefinition dashboard,
  ) async {
    final linesAffected = await logic.upsertDashboardDefinition(
      dashboard.copyWith(
        deletedAt: DateTime.now(),
      ),
    );

    await getIt<NotificationService>().cancelNotification(
      dashboard.id.hashCode,
    );

    return linesAffected;
  }
}
