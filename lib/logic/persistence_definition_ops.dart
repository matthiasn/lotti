import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
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
    if (previous?.status != configFlag.status) {
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
    if (configFlag.name == enableNotificationsFlag &&
        previous?.status != configFlag.status) {
      await _refreshBadgeForNotificationsFlag();
      if (configFlag.status) {
        // Rows written while the flag was off carry no OS alarm — the
        // scheduler's platform calls are gated on the flag, and the
        // repository's idempotent creates never re-schedule an existing row.
        // Without this, only the next app start would arm them, so a user
        // who turns notifications on and keeps the app running would miss
        // every reminder already sitting in the database.
        await reconcileScheduledNotifications(
          scheduler: getIt<NotificationScheduler>(),
          logger: getIt<DomainLogger>(),
        );
      }
    }
  }

  /// Makes the app icon reflect the notifications flag the moment it is
  /// toggled, rather than at the next journal write.
  ///
  /// `updateBadge` is the only thing that reconciles the icon with the flag,
  /// and nothing else calls it outside entry creation — so without this,
  /// switching notifications off left the task count sitting on the icon until
  /// the user happened to write something. Turning them *on* is where the
  /// permission prompt now surfaces, which is the moment the user asked for it.
  ///
  /// Failure is logged and swallowed: the user asked to change a setting, and
  /// that write has already succeeded. A badge refresh that cannot reach the
  /// platform is not a reason to report the setting as unsaved.
  Future<void> _refreshBadgeForNotificationsFlag() async {
    try {
      await getIt<NotificationService>().updateBadge();
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.notifications,
        exception,
        stackTrace: stackTrace,
        subDomain: 'setConfigFlag',
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
