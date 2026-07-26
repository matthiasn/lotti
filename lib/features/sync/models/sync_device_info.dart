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

  /// The name shown to the user, falling back to the raw device id.
  String get label {
    final name = displayName;
    if (name != null && name.trim().isNotEmpty) return name;
    return deviceId;
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

/// Orders devices for display: the current device first, then devices that
/// block sync (they need action), then the rest by recency of last-seen with
/// unreported timestamps last.
List<SyncDeviceInfo> sortSyncDevicesForDisplay(List<SyncDeviceInfo> devices) {
  int recency(SyncDeviceInfo d) => d.lastSeen?.millisecondsSinceEpoch ?? -1;

  final sorted = [...devices]
    ..sort((a, b) {
      if (a.isCurrentDevice != b.isCurrentDevice) {
        return a.isCurrentDevice ? -1 : 1;
      }
      if (a.blocksSync != b.blocksSync) {
        return a.blocksSync ? -1 : 1;
      }
      return recency(b).compareTo(recency(a));
    });
  return sorted;
}
