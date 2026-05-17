import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/get_it.dart';

/// Stores the local node's own profile and the directory of profiles received
/// from peers.
///
/// Two values live in [SettingsDb]:
/// - `sync_node_profile_self` — the local node's own profile as JSON.
/// - `sync_node_profile_directory` — a JSON object keyed by `hostId` whose
///   values are the latest [SyncNodeProfile] snapshot for each known peer.
///
/// Both are tiny relative to the rest of the settings table (a few hundred
/// bytes per node), and the directory is read/written rarely (pinning UI, and
/// on each incoming `SyncSyncNodeProfile` apply). A dedicated Drift table
/// would be overkill for the cardinality involved.
class SyncNodeProfileRepository {
  SyncNodeProfileRepository({SettingsDb? settingsDb})
    : _settingsDb = settingsDb ?? getIt<SettingsDb>();

  final SettingsDb _settingsDb;

  /// Storage key for the local node's own profile.
  static const String selfKey = 'sync_node_profile_self';

  /// Storage key for the directory of known peer profiles.
  static const String directoryKey = 'sync_node_profile_directory';

  final StreamController<List<SyncNodeProfile>> _directoryController =
      StreamController<List<SyncNodeProfile>>.broadcast();

  /// Emits the directory contents (sorted by displayName) whenever an upsert
  /// changes it. UI code can listen here for live updates.
  Stream<List<SyncNodeProfile>> watchKnownNodes() =>
      _directoryController.stream;

  /// Reads the local node's own profile, or null if none has been written yet.
  Future<SyncNodeProfile?> getSelf() async {
    final raw = await _settingsDb.itemByKey(selfKey);
    if (raw == null || raw.isEmpty) return null;
    return _decodeProfile(raw);
  }

  /// Persists the local node's own profile. Does not broadcast — the
  /// `SyncNodeProfileBroadcaster` owns the diff/broadcast cycle so callers
  /// don't accidentally send a copy of the previous snapshot.
  Future<void> setSelf(SyncNodeProfile profile) async {
    await _settingsDb.saveSettingsItem(selfKey, jsonEncode(profile.toJson()));
  }

  /// Returns every peer profile in the directory, sorted by displayName then
  /// hostId for stable iteration in tests and UI.
  Future<List<SyncNodeProfile>> listKnownNodes() async {
    final directory = await _readDirectory();
    final result = directory.values.toList(growable: false)
      ..sort((a, b) {
        final byName = a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
        if (byName != 0) return byName;
        return a.hostId.compareTo(b.hostId);
      });
    return result;
  }

  /// Looks up a peer profile by host id.
  Future<SyncNodeProfile?> getNode(String hostId) async {
    final directory = await _readDirectory();
    return directory[hostId];
  }

  /// Upserts a peer profile into the directory.
  ///
  /// Last-write-wins by [SyncNodeProfile.updatedAt]: an incoming snapshot with
  /// an older timestamp than the one already stored for the same `hostId` is
  /// dropped. This matters during reconnect waves where multiple snapshots
  /// for the same node can land out of order.
  ///
  /// Returns true if the directory changed; false if the incoming profile was
  /// stale or identical to what was already stored.
  Future<bool> upsertNode(SyncNodeProfile profile) async {
    final directory = await _readDirectory();
    final existing = directory[profile.hostId];
    if (existing != null) {
      // Stale snapshot — drop.
      if (existing.updatedAt.isAfter(profile.updatedAt)) return false;
      // No-op upsert — same content.
      if (existing == profile) return false;
    }
    directory[profile.hostId] = profile;
    await _writeDirectory(directory);
    final sorted = await listKnownNodes();
    if (_directoryController.hasListener) {
      _directoryController.add(sorted);
    }
    return true;
  }

  /// Removes a peer profile. Returns true if the directory changed.
  Future<bool> removeNode(String hostId) async {
    final directory = await _readDirectory();
    if (!directory.containsKey(hostId)) return false;
    directory.remove(hostId);
    await _writeDirectory(directory);
    final sorted = await listKnownNodes();
    if (_directoryController.hasListener) {
      _directoryController.add(sorted);
    }
    return true;
  }

  Future<Map<String, SyncNodeProfile>> _readDirectory() async {
    final raw = await _settingsDb.itemByKey(directoryKey);
    if (raw == null || raw.isEmpty) {
      return <String, SyncNodeProfile>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, SyncNodeProfile>{};
    }
    final result = <String, SyncNodeProfile>{};
    decoded.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final parsed = _tryDecodeProfileMap(value);
        if (parsed != null) {
          result[key] = parsed;
        }
      }
    });
    return result;
  }

  Future<void> _writeDirectory(Map<String, SyncNodeProfile> directory) async {
    final encoded = <String, dynamic>{
      for (final entry in directory.entries) entry.key: entry.value.toJson(),
    };
    await _settingsDb.saveSettingsItem(directoryKey, jsonEncode(encoded));
  }

  SyncNodeProfile? _decodeProfile(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return _tryDecodeProfileMap(decoded);
    } catch (_) {
      return null;
    }
  }

  SyncNodeProfile? _tryDecodeProfileMap(Map<String, dynamic> map) {
    try {
      return SyncNodeProfile.fromJson(map);
    } catch (_) {
      // Future fields, schema drift, or hand-corrupted settings would crash
      // listKnownNodes() if we didn't swallow per-row decode errors. Drop the
      // bad row, keep the rest of the directory readable.
      return null;
    }
  }

  Future<void> dispose() async {
    await _directoryController.close();
  }
}

/// Exposes the single get_it-registered [SyncNodeProfileRepository] to
/// Riverpod consumers.
///
/// Crucial: this MUST return the get_it singleton, not a fresh instance. The
/// production sync apply path writes through the singleton injected into
/// `SyncEventProcessor`; if this provider built its own repository, any UI
/// watching it would miss directory upserts that arrive over Matrix.
final syncNodeProfileRepositoryProvider = Provider<SyncNodeProfileRepository>(
  (ref) => getIt<SyncNodeProfileRepository>(),
);
