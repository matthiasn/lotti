import 'package:matrix/matrix.dart';

/// A device is considered stale when the homeserver last saw it longer than
/// this ago — a strong hint that the session belongs to an uninstalled or
/// abandoned install and should be removed rather than verified.
const Duration syncDeviceStaleThreshold = Duration(days: 30);

/// One session on the sync account, merged from the homeserver's device list
/// (`GET /devices`: display name, last-seen) and the E2EE device-key cache
/// (verification state).
///
/// The homeserver list is the authoritative inventory: sessions that never
/// published encryption keys (e.g. an install that died mid-provisioning)
/// appear here with [keys] == null. Such sessions cannot be verified — there
/// is nothing to verify — and do not block sync; they can only be removed.
class SyncDeviceInfo {
  const SyncDeviceInfo({
    required this.deviceId,
    required this.isCurrentDevice,
    required this.verified,
    this.displayName,
    this.lastSeen,
    this.keys,
    this.onServer = true,
    this.ownAccount = true,
    this.userId,
  });

  final String deviceId;
  final String? displayName;

  /// When the homeserver last saw this session, or null when unreported.
  final DateTime? lastSeen;

  /// Whether this is the session the app itself is running as.
  final bool isCurrentDevice;

  /// Whether the local session has verified this device. Always considered
  /// true for [isCurrentDevice]; false for sessions without published keys.
  final bool verified;

  /// The published encryption keys, when the device has any. Required for
  /// starting a verification; null for keyless sessions.
  final DeviceKeys? keys;

  /// Whether the homeserver still lists this session. A cache-only entry
  /// (unverified keys the server no longer knows) blocks sends but can never
  /// answer a verification — removal is its only remedy.
  final bool onServer;

  /// Whether the session belongs to this account. Legacy cross-user rooms
  /// run one Matrix user per device: their unverified devices gate sends and
  /// can be SAS-verified, but only own-account sessions can be deleted.
  final bool ownAccount;

  /// The Matrix user the session belongs to, when known. Device ids are only
  /// unique per user, so roster identity is the (user, device) pair.
  final String? userId;

  /// The name shown to the user, falling back to the raw device id.
  String get label {
    final name = displayName;
    if (name != null && name.trim().isNotEmpty) return name;
    return deviceId;
  }

  /// Matches the machine-generated suffix `createMatrixDeviceName()` appends:
  /// an ISO date-to-minutes pairing timestamp plus a uuid fragment.
  static final RegExp _generatedNameSuffix = RegExp(
    r'\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}.*)$',
  );

  /// The human-recognizable part of [label] — the host name for generated
  /// names, the full label otherwise.
  String get titleLabel {
    final match = _generatedNameSuffix.firstMatch(label);
    return match == null ? label : label.substring(0, match.start);
  }

  /// The machine-generated remainder of a generated [label] (pairing date +
  /// hash), or null when the label carries no such suffix.
  String? get metaLabel => _generatedNameSuffix.firstMatch(label)?.group(1);

  /// When the session was paired, parsed from a generated [label] suffix.
  DateTime? get pairedAt {
    final meta = metaLabel;
    if (meta == null) return null;
    final timestamp = meta.split(' ').first;
    return DateTime.tryParse(timestamp);
  }

  /// The uuid fragment of a generated [label] suffix, or null.
  String? get pairingHash {
    final meta = metaLabel;
    if (meta == null) return null;
    final parts = meta.split(' ');
    return parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  }

  /// Whether this device blocks outbound sync: it has published keys the
  /// send path counts as an unverified peer.
  bool get blocksSync => !isCurrentDevice && !verified && keys != null;

  bool isStaleAt(DateTime now) {
    final seen = lastSeen;
    if (seen == null) return false;
    return now.difference(seen) > syncDeviceStaleThreshold;
  }
}

/// Orders devices for display: devices that block sync first — they are what
/// the paused banner points at, so they sit directly beneath it — then the
/// current device, then the rest by recency of last-seen with unreported
/// timestamps last.
List<SyncDeviceInfo> sortSyncDevicesForDisplay(List<SyncDeviceInfo> devices) {
  int recency(SyncDeviceInfo d) => d.lastSeen?.millisecondsSinceEpoch ?? -1;

  final sorted = [...devices]
    ..sort((a, b) {
      if (a.blocksSync != b.blocksSync) {
        return a.blocksSync ? -1 : 1;
      }
      if (a.isCurrentDevice != b.isCurrentDevice) {
        return a.isCurrentDevice ? -1 : 1;
      }
      return recency(b).compareTo(recency(a));
    });
  return sorted;
}
