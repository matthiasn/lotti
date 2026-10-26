import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/sync_key_value_store.dart';
import 'package:lotti/database/sync_payload_source.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// The host services over the UI isolate's own databases (ADR 0142, step
/// 4b): what the worker's Matrix stack asks for is answered from `SettingsDb`,
/// `JournalDb`, the vector clock and the agent-clock dominance check, all of
/// which stay where they are.
class DatabaseSyncIsolateHostServices implements SyncIsolateHostServices {
  const DatabaseSyncIsolateHostServices({
    required SyncKeyValueStore settings,
    required SyncPayloadSource journal,
    required SyncHostIdSource vectorClock,
    required LocalVectorClockDominanceCheck localVcDominance,
  }) : this._(settings, journal, vectorClock, localVcDominance);

  const DatabaseSyncIsolateHostServices._(
    this._settings,
    this._journal,
    this._vectorClock,
    this._localVcDominance,
  );

  final SyncKeyValueStore _settings;
  final SyncPayloadSource _journal;
  final SyncHostIdSource _vectorClock;
  final LocalVectorClockDominanceCheck _localVcDominance;

  @override
  Future<String?> settingsGet(String key) => _settings.itemByKey(key);

  @override
  Future<int> settingsSet(String key, String value) =>
      _settings.saveSettingsItem(key, value);

  @override
  Future<void> settingsRemove(String key) => _settings.removeSettingsItem(key);

  @override
  Future<Map<String, JournalEntity>> journalEntities(List<String> ids) =>
      _journal.journalEntityMapForIdsIncludingDeleted(ids);

  @override
  Future<JournalEntity?> openConflictVersion(
    String id,
    VectorClock vectorClock,
  ) => _journal.openConflictVersion(id, vectorClock);

  @override
  Future<bool> configFlag(String flagName) => _journal.getConfigFlag(flagName);

  @override
  Future<String?> vectorClockHost() => _vectorClock.getHost();

  @override
  Future<bool> localVcDominates(
    String relativePath,
    VectorClock? incomingVectorClock,
  ) => _localVcDominance(relativePath, incomingVectorClock);
}
