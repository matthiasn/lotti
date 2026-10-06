import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/logic/config_flag_effects.dart';
import 'package:lotti/logic/persistence_collaborator_base.dart';
import 'package:lotti/logic/persistence_logic.dart' show PersistenceLogic;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';

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

  /// Writes [definition] only when no copy of it is stored, under a fresh
  /// own counter but with its `updatedAt` as given, then announces and
  /// sends it.
  ///
  /// For definitions a device derives on its own rather than a user's edit,
  /// such as migrated speech dictionary entries: whatever is stored, written
  /// here or arrived from another device, must win over them, and a seed
  /// that meets another device's copy later loses to any newer `updatedAt`.
  /// Returns the write's row count, 0 when a copy was stored and nothing was
  /// written or sent.
  Future<int> seedEntityDefinitionImpl(EntityDefinition definition) async {
    final seeded = await vectorClockService.withVcScope<EntityDefinition?>(
      () => journalDb.transaction(() async {
        if (await journalDb.definitionStamp(definition) != null) return null;
        final stamped = definition.copyWith(
          vectorClock: await vectorClockService.getNextVectorClock(
            payload: _payloadOf(definition),
          ),
        );
        final linesAffected = await journalDb.upsertEntityDefinition(stamped);
        return linesAffected == 0 ? null : stamped;
      }),
      commitWhen: (seeded) => seeded != null,
    );
    if (seeded == null) return 0;
    updateNotifications.notify({
      seeded.id,
      _typeNotification(seeded),
    });
    await outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: seeded,
        status: SyncEntryStatus.update,
      ),
    );
    return 1;
  }

  static VcPayloadRef _payloadOf(EntityDefinition definition) =>
      (id: definition.id, type: SyncSequencePayloadType.entityDefinition);

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
  /// The edit is a new version of what is stored: it carries this host's
  /// next counter on top of the stored vector clock, so it dominates every
  /// version this device has seen and supersedes them on every peer
  /// (DefinitionClocks.tla). Its `updatedAt` goes strictly above the stored
  /// one when the caller's does not — a stale editor, a delete that kept the
  /// old stamp, or a peer whose clock runs ahead — so it also wins
  /// last-writer-wins against a concurrent version written before it.
  ///
  /// The stored stamp is read, the counter reserved and the edit written in
  /// one transaction, so no sync arrival can land in between: the gate
  /// always accepts the edit. Were the write still refused, the reservation
  /// is released and its counter burned.
  ///
  /// Returns the definition that was actually stored with the write's row
  /// count, or null when it was refused — then nothing was saved, and the
  /// caller must neither announce nor sync it.
  Future<(EntityDefinition, int)?> _writeLocalEdit(
    EntityDefinition definition,
    Future<int> Function(EntityDefinition definition) write,
  ) {
    return vectorClockService.withVcScope<(EntityDefinition, int)?>(
      () => journalDb.transaction(() async {
        final stored = await journalDb.definitionStamp(definition);
        final floor = stored?.updatedAt;
        final edit = definition.copyWith(
          updatedAt: floor == null || definition.updatedAt.isAfter(floor)
              ? definition.updatedAt
              : floor.add(const Duration(milliseconds: 1)),
          vectorClock: await vectorClockService.getNextVectorClock(
            previous: stored?.vectorClock,
            payload: _payloadOf(definition),
          ),
        );
        final linesAffected = await write(edit);
        if (linesAffected == 0) {
          loggingService.error(
            LogDomain.persistence,
            StateError('Local definition edit ${definition.id} refused'),
            subDomain: 'upsertEntityDefinition.refused',
          );
          return null;
        }
        return (edit, linesAffected);
      }),
      commitWhen: (written) => written != null,
    );
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
