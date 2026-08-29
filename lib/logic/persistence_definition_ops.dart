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
    EntityDefinition entityDefinition,
  ) async {
    final previousMeasurable = entityDefinition is MeasurableDataType
        ? await journalDb.getMeasurableDataTypeById(entityDefinition.id)
        : null;
    final linesAffected = await journalDb.upsertEntityDefinition(
      entityDefinition,
    );
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

  Future<void> _reindexMeasurements(MeasurableDataType dataType) async {
    try {
      final entries = await journalDb.getMeasurementsByType(
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
    DashboardDefinition dashboard,
  ) async {
    final linesAffected = await journalDb.upsertDashboardDefinition(dashboard);
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
