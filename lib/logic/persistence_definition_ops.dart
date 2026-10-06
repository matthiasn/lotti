import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/logic/config_flag_effects.dart';
import 'package:lotti/logic/persistence_collaborator_base.dart';
import 'package:lotti/logic/persistence_logic.dart' show PersistenceLogic;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// Entity/dashboard definition and config-flag operations of
/// [PersistenceLogic].
class PersistenceDefinitionOps extends PersistenceCollaboratorBase {
  PersistenceDefinitionOps(super.logic, super.services);

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
    updateNotifications.notify({
      entityDefinition.id,
      _typeNotification(entityDefinition),
    });
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

  /// Writes [definition] only if the recency gate accepts it as it is —
  /// never re-stamped past a stored copy — then announces and sends it.
  ///
  /// For definitions a device derives on its own rather than a user's edit,
  /// such as migrated speech dictionary entries: whatever is stored, written
  /// here or arrived from another device, must win over them. Returns the
  /// write's row count, 0 when the stored copy won and nothing was sent.
  Future<int> seedEntityDefinitionImpl(EntityDefinition definition) async {
    final linesAffected = await journalDb.upsertEntityDefinition(definition);
    if (linesAffected == 0) return 0;
    updateNotifications.notify({
      definition.id,
      _typeNotification(definition),
    });
    await outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: definition,
        status: SyncEntryStatus.update,
      ),
    );
    return linesAffected;
  }

  static String _typeNotification(EntityDefinition definition) =>
      switch (definition) {
        CategoryDefinition() => categoriesNotification,
        HabitDefinition() => habitsNotification,
        DashboardDefinition() => dashboardsNotification,
        MeasurableDataType() => measurablesNotification,
        LabelDefinition() => labelsNotification,
        SpeechDictionaryEntry() => speechDictionaryNotification,
      };

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
      await fts5Db.reindexMeasurements(dataType, entries);
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
      await notificationService.cancelNotification(
        dashboard.id.hashCode,
      );
    }

    return linesAffected;
  }

  /// Commits a local version before publishing or applying platform effects.
  Future<void> setConfigFlagImpl(ConfigFlag configFlag) async {
    final result = await journalDb.saveLocalConfigFlag(
      configFlag,
      timestamp: clock.now().millisecondsSinceEpoch,
    );
    if (result.applied) {
      await outboxService.enqueueMessage(
        SyncMessage.configFlag(
          name: result.flag.name,
          description: result.flag.description,
          status: result.flag.status,
          updatedAt: result.updatedAt,
        ),
      );
    }
    if (configFlag.name == 'private') {
      updateNotifications.notify({privateToggleNotification});
    }
    if (result.statusChanged) {
      await _applyNotificationPreference(result.flag);
    }
  }

  /// Makes a notification preference take effect the moment it is toggled,
  /// rather than at the next journal write or the next app start. The
  /// consequences live in the registered [ConfigFlagEffects] — the
  /// notifications feature's preference effects, shared with the sync apply
  /// path so a flag flipped on a peer reaches this device's alarms as well.
  Future<void> _applyNotificationPreference(ConfigFlag flag) =>
      configFlagEffects.apply(flag);

  Future<int> deleteDashboardDefinitionImpl(
    DashboardDefinition dashboard,
  ) async {
    final linesAffected = await logic.upsertDashboardDefinition(
      dashboard.copyWith(
        deletedAt: DateTime.now(),
      ),
    );

    await notificationService.cancelNotification(
      dashboard.id.hashCode,
    );

    return linesAffected;
  }
}
