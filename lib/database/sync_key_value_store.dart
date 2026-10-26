/// The few settings keys the Matrix stack reads and writes — the sync room
/// id, the legacy last-read marker, the megolm rotation marker — as a store
/// the stack can hold without holding `SettingsDb` (ADR 0142).
///
/// In-process the store is `SettingsDb` itself, which implements this. In
/// the sync isolate, which owns no settings connection, it is answered by
/// the UI isolate over the port; the key names stay the same on both sides.
abstract interface class SyncKeyValueStore {
  /// The value stored under [key], or null.
  Future<String?> itemByKey(String key);

  /// Stores [value] under [key], replacing what was there.
  Future<int> saveSettingsItem(String key, String value);

  /// Removes [key]; a missing key is not an error.
  Future<void> removeSettingsItem(String key);
}
