import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/providers/service_providers.dart';

/// A set of keys this device remembers under [settingsKey] in `SettingsDb`,
/// stored as a sorted JSON list.
///
/// Device-local, like the rest of `SettingsDb`: what a suggestion list hides
/// once the user dismissed an entry is a reading preference for that list,
/// not a change to the journal, so it rides on no synced entity. A missing or
/// unreadable value reads as the empty set.
abstract class DeviceLocalKeySet extends AsyncNotifier<Set<String>> {
  /// The `SettingsDb` key the set is stored under.
  String get settingsKey;

  @override
  Future<Set<String>> build() async {
    final raw = await ref.read(settingsDbProvider).itemByKey(settingsKey);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.whereType<String>().toSet() : const {};
    } on FormatException {
      return const {};
    }
  }

  /// Remembers [key] on this device for good. Publishes before it writes,
  /// so the list the key hides drops it at once.
  Future<void> addKey(String key) async {
    final current = state.value ?? await future;
    if (current.contains(key)) return;
    final next = {...current, key};
    state = AsyncData(next);
    await ref
        .read(settingsDbProvider)
        .saveSettingsItem(settingsKey, jsonEncode(next.toList()..sort()));
  }
}
