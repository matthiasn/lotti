part of 'sync_isolate_protocol.dart';

// The worker asks the UI isolate for the few things it owns that the Matrix
// stack reads (ADR 0142, step 4b): settings keys, the sender's journal rows,
// the vector clock's host id and the agent-clock dominance check. The host
// answers each on the worker's command port with a [SyncIsolateHostReply].

/// Something the worker asks the host. Each query has exactly one reply; the
/// result type each one answers with is documented on it.
sealed class SyncIsolateHostQuery {
  const SyncIsolateHostQuery();
}

/// The settings value under [key]. Answered with `String?`.
final class SyncIsolateHostSettingsGet extends SyncIsolateHostQuery {
  const SyncIsolateHostSettingsGet(this.key);

  final String key;
}

/// Stores [value] under [key]. Answered with the `int` the store reports.
final class SyncIsolateHostSettingsSet extends SyncIsolateHostQuery {
  const SyncIsolateHostSettingsSet(this.key, this.value);

  final String key;
  final String value;
}

/// Removes [key]. Answered with `null`.
final class SyncIsolateHostSettingsRemove extends SyncIsolateHostQuery {
  const SyncIsolateHostSettingsRemove(this.key);

  final String key;
}

/// The journal rows for [ids], deleted ones included. Answered with
/// `Map<String, JournalEntity>`.
final class SyncIsolateHostJournalEntities extends SyncIsolateHostQuery {
  const SyncIsolateHostJournalEntities(this.ids);

  final List<String> ids;
}

/// The open conflict version of [id] stamped [vectorClock]. Answered with
/// `JournalEntity?`.
final class SyncIsolateHostOpenConflictVersion extends SyncIsolateHostQuery {
  const SyncIsolateHostOpenConflictVersion({
    required this.id,
    required this.vectorClock,
  });

  final String id;
  final VectorClock vectorClock;
}

/// A journal config flag. Answered with `bool`.
final class SyncIsolateHostConfigFlag extends SyncIsolateHostQuery {
  const SyncIsolateHostConfigFlag(this.flagName);

  final String flagName;
}

/// This device's vector-clock host id. Answered with `String?`.
final class SyncIsolateHostVectorClockHost extends SyncIsolateHostQuery {
  const SyncIsolateHostVectorClockHost();
}

/// Whether the local agent record at [relativePath] already dominates
/// [incomingVectorClock], so ingestion may skip the download. Answered with
/// `bool`.
final class SyncIsolateHostLocalVcDominates extends SyncIsolateHostQuery {
  const SyncIsolateHostLocalVcDominates({
    required this.relativePath,
    required this.incomingVectorClock,
  });

  final String relativePath;
  final VectorClock? incomingVectorClock;
}

/// A [query] on its way to the host, numbered so its reply finds the worker
/// waiting for it.
final class SyncIsolateHostRequest {
  const SyncIsolateHostRequest({required this.requestId, required this.query});

  final int requestId;
  final SyncIsolateHostQuery query;
}

/// The host's answer to the request numbered [requestId].
final class SyncIsolateHostReply {
  const SyncIsolateHostReply.success(this.requestId, this.result)
    : failure = null;

  const SyncIsolateHostReply.failure(
    this.requestId,
    SyncIsolateFailure this.failure,
  ) : result = null;

  final int requestId;
  final Object? result;
  final SyncIsolateFailure? failure;
}

/// What the host answers the worker's queries from: the UI isolate's own
/// databases and services, behind an interface a test can fake.
abstract interface class SyncIsolateHostServices {
  Future<String?> settingsGet(String key);

  Future<int> settingsSet(String key, String value);

  Future<void> settingsRemove(String key);

  Future<Map<String, JournalEntity>> journalEntities(List<String> ids);

  Future<JournalEntity?> openConflictVersion(
    String id,
    VectorClock vectorClock,
  );

  Future<bool> configFlag(String flagName);

  Future<String?> vectorClockHost();

  Future<bool> localVcDominates(
    String relativePath,
    VectorClock? incomingVectorClock,
  );
}
