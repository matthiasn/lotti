import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/repository/sync_node_profile_repository.dart';
import 'package:lotti/features/sync/services/sync_node_capability_probe.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Probes the local node's capabilities, persists the snapshot as the "self"
/// profile, and broadcasts it over Matrix when it differs from the previously
/// published snapshot.
///
/// Invoked on startup and whenever the user edits their device's display name.
/// All calls are idempotent — a no-op when nothing has changed since the last
/// broadcast — so callers can invoke [broadcastIfChanged] without coordinating
/// against each other.
class SyncNodeProfileBroadcaster {
  SyncNodeProfileBroadcaster({
    required this._repository,
    required this._probe,
    required this._vectorClockService,
    required this._outboxService,
    this._domainLogger,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SyncNodeProfileRepository _repository;
  final SyncNodeCapabilityProbe _probe;
  final VectorClockService _vectorClockService;
  final OutboxService _outboxService;
  final DomainLogger? _domainLogger;
  final DateTime Function() _clock;

  /// Probes capabilities and unconditionally broadcasts the resulting profile.
  ///
  /// Called on every app startup so peers that joined late, wiped settings,
  /// or missed the last Matrix event always converge on the current snapshot
  /// within a session. The receiver-side directory uses last-write-wins by
  /// `updatedAt`, so a redundant re-broadcast of unchanged content is cheap
  /// and self-deduplicating.
  ///
  /// For the rename UI path, prefer [broadcastIfChanged] — it suppresses the
  /// no-op case where the user re-saved the same name.
  Future<bool> broadcast({
    String? displayNameOverride,
    String? appVersion,
  }) async {
    return _broadcast(
      displayNameOverride: displayNameOverride,
      appVersion: appVersion,
      skipWhenUnchanged: false,
    );
  }

  /// Probes capabilities and broadcasts the resulting profile only when it
  /// differs from the last published self profile.
  ///
  /// Pass [displayNameOverride] when the user has explicitly renamed the
  /// device — the override beats whatever the probe would compute. When null,
  /// any previously-persisted display name on the self profile is kept (so
  /// startup probes don't reset the user's chosen name back to a hostname).
  ///
  /// Returns true if a broadcast was issued, false if nothing changed.
  Future<bool> broadcastIfChanged({
    String? displayNameOverride,
    String? appVersion,
  }) async {
    return _broadcast(
      displayNameOverride: displayNameOverride,
      appVersion: appVersion,
      skipWhenUnchanged: true,
    );
  }

  Future<bool> _broadcast({
    required bool skipWhenUnchanged,
    String? displayNameOverride,
    String? appVersion,
  }) async {
    final hostId = await _vectorClockService.getHost();
    if (hostId == null) {
      _domainLogger?.log(
        LogDomains.sync,
        'syncNodeProfile.broadcast skipped: no host id',
        subDomain: 'broadcaster',
      );
      return false;
    }

    final existingSelf = await _repository.getSelf();
    // Null means "let the probe pick its default display name".
    final displayName = displayNameOverride ?? existingSelf?.displayName;

    final probed = await _probe(
      hostId: hostId,
      displayName: displayName,
      appVersion: appVersion,
      now: _clock(),
    );

    // Compare on everything except updatedAt — a fresh timestamp on identical
    // content is not worth a broadcast when the caller opted into diffing.
    if (skipWhenUnchanged &&
        existingSelf != null &&
        _contentMatches(existingSelf, probed)) {
      _domainLogger?.log(
        LogDomains.sync,
        'syncNodeProfile.broadcast skipped: unchanged',
        subDomain: 'broadcaster',
      );
      return false;
    }

    await _repository.setSelf(probed);
    await _outboxService.enqueueMessage(
      SyncMessage.syncNodeProfile(profile: probed),
    );
    _domainLogger?.log(
      LogDomains.sync,
      'syncNodeProfile.broadcast issued '
      'hostId=$hostId name=${probed.displayName} '
      'caps=${probed.capabilities.length}',
      subDomain: 'broadcaster',
    );
    return true;
  }

  /// Persists a new display name and triggers a broadcast.
  Future<void> setDisplayName(String displayName, {String? appVersion}) async {
    await broadcastIfChanged(
      displayNameOverride: displayName,
      appVersion: appVersion,
    );
  }

  bool _contentMatches(SyncNodeProfile a, SyncNodeProfile b) {
    return a.hostId == b.hostId &&
        a.displayName == b.displayName &&
        a.platform == b.platform &&
        a.osVersion == b.osVersion &&
        a.cpuModel == b.cpuModel &&
        a.ramMb == b.ramMb &&
        a.gpuModel == b.gpuModel &&
        a.appVersion == b.appVersion &&
        _listEquals(a.capabilities, b.capabilities);
  }

  bool _listEquals(List<NodeCapability> a, List<NodeCapability> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
