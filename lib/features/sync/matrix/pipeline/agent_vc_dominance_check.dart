import 'dart:convert';

import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Callback shape the `AttachmentIngestor` expects.
typedef LocalVcDominatesFn =
    Future<bool> Function(String relativePath, VectorClock? incomingVc);

/// Decides whether the local copy of an agent entity / link already
/// carries a vector clock equal to or newer than the one advertised
/// by an incoming sync-message attachment. When `true`, the ingestor
/// skips the proactive download — re-fetching the file would just
/// rewrite bytes the device already has.
///
/// Two optimisations over a naive per-event lookup:
///
///   1. Narrow projection. Reads only the JSON-extracted
///      `vector_clock` field from `agent_entities` / `agent_links`
///      instead of `SELECT *`, which would deserialize the full
///      `serialized` JSON blob. Measured at ~36 ms avg / 101 ms p95
///      / 239 ms max per call on a desktop mid-drain, 1631 times
///      per hour before this change.
///
///   2. Short-lived id → VC cache. Chatty senders emit multiple
///      echoes of the same entity within seconds; without a cache
///      each echo paid the full lookup. The cache is bounded in
///      capacity and TTL so edits made after the first lookup land
///      through a subsequent eviction rather than being masked.
class AgentVcDominanceCheck {
  AgentVcDominanceCheck({
    required AgentDatabase agentDb,
    Duration cacheTtl = const Duration(seconds: 5),
    int cacheCapacity = 256,
    DateTime Function()? now,
  }) : _agentDb = agentDb,
       _cacheTtl = cacheTtl,
       _cacheCapacity = cacheCapacity,
       _now = now ?? DateTime.now;

  final AgentDatabase _agentDb;
  final Duration _cacheTtl;
  final int _cacheCapacity;
  final DateTime Function() _now;

  final _entityCache = <String, _CachedVc>{};
  final _linkCache = <String, _CachedVc>{};

  /// Extract the entity/link id from an agent attachment's relativePath.
  /// Paths look like `/agent_entities/<uuid>.json` or
  /// `/agent_links/<uuid>.json`. Returns null if the path doesn't match
  /// the expected shape.
  static String? idFromPath(String relativePath) {
    final name = relativePath.split('/').lastOrNull;
    if (name == null || !name.endsWith('.json')) return null;
    return name.substring(0, name.length - '.json'.length);
  }

  /// Returns `true` when the local VC dominates or matches [incomingVc]
  /// — i.e. the caller can safely skip the download. Conservative on
  /// every edge case (null incoming VC, unparseable path, no local
  /// row, concurrent clocks, malformed local VC): all return `false`
  /// so the caller proceeds with the download.
  Future<bool> check(String relativePath, VectorClock? incomingVc) async {
    if (incomingVc == null) return false;
    final id = idFromPath(relativePath);
    if (id == null) return false;
    VectorClock? localVc;
    if (relativePath.contains('/agent_entities/')) {
      localVc = await _vectorClockFor(
        cache: _entityCache,
        id: id,
        loader: () =>
            _agentDb.getAgentEntityVectorClockById(id).getSingleOrNull(),
      );
    } else if (relativePath.contains('/agent_links/')) {
      localVc = await _vectorClockFor(
        cache: _linkCache,
        id: id,
        loader: () =>
            _agentDb.getAgentLinkVectorClockById(id).getSingleOrNull(),
      );
    } else {
      return false;
    }
    if (localVc == null) return false;
    try {
      final status = VectorClock.compare(localVc, incomingVc);
      return status == VclockStatus.a_gt_b || status == VclockStatus.equal;
    } catch (_) {
      return false;
    }
  }

  Future<VectorClock?> _vectorClockFor({
    required Map<String, _CachedVc> cache,
    required String id,
    required Future<String?> Function() loader,
  }) async {
    final now = _now();
    final cached = cache[id];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.vc;
    }
    final raw = await loader();
    VectorClock? vc;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          vc = VectorClock.fromJson(decoded);
        }
      } catch (_) {
        // Malformed VC JSON — fall through with vc=null so the caller
        // proceeds with the download rather than silently succeeding.
      }
    }
    cache[id] = _CachedVc(vc: vc, expiresAt: now.add(_cacheTtl));
    if (cache.length > _cacheCapacity) {
      cache.remove(cache.keys.first);
    }
    return vc;
  }
}

class _CachedVc {
  _CachedVc({required this.vc, required this.expiresAt});
  final VectorClock? vc;
  final DateTime expiresAt;
}
