import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/utils.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';

class VectorClockService {
  VectorClockService() {
    init();
  }
  late int _nextAvailableCounter;
  late String _host;
  Future<void>? _lock;

  Future<void> init() async {
    _host = await _getHost() ?? await setNewHost();
    await _getNextAvailableCounter();
  }

  Future<void> increment() async {
    final next = await getNextAvailableCounter() + 1;
    await setNextAvailableCounter(next);
  }

  Future<String> setNewHost() async {
    final host = uuid.v4();

    await getIt<SettingsDb>().saveSettingsItem(hostKey, host);
    await setNextAvailableCounter(0);

    _host = host;
    return host;
  }

  Future<String?> _getHost() async {
    return getIt<SettingsDb>().itemByKey(hostKey);
  }

  Future<String?> getHost() async {
    return _host;
  }

  Future<void> setNextAvailableCounter(int nextAvailableCounter) async {
    _nextAvailableCounter = nextAvailableCounter;

    await getIt<SettingsDb>().saveSettingsItem(
      nextAvailableCounterKey,
      nextAvailableCounter.toString(),
    );
  }

  Future<void> _getNextAvailableCounter() async {
    final existing = await getIt<SettingsDb>()
        .watchSettingsItemByKey(nextAvailableCounterKey)
        .first;

    if (existing.isNotEmpty) {
      _nextAvailableCounter = int.parse(existing.first.value);
    } else {
      await setNextAvailableCounter(0);
    }
  }

  Future<int> getNextAvailableCounter() async {
    return _nextAvailableCounter;
  }

  Future<String?> getHostHash() async {
    final host = await getHost();

    if (host == null) {
      return null;
    }

    final bytes = utf8.encode(host);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  // TODO: only increment after successful insertion
  Future<VectorClock> getNextVectorClock({VectorClock? previous}) async {
    // Wait for any pending operation to complete (mutex pattern)
    while (_lock != null) {
      await _lock;
    }

    final completer = Completer<void>();
    _lock = completer.future;

    try {
      // Check if the previous clock has a higher counter for our host than
      // our local _nextAvailableCounter. This handles cases where the DB was
      // copied/synced and has higher counters than our local counter.
      final previousHostCounter = previous?.vclock[_host];
      final int effectiveCounter;

      if (previousHostCounter != null &&
          previousHostCounter >= _nextAvailableCounter) {
        // Previous clock has a counter >= ours for our host - catch up
        effectiveCounter = previousHostCounter + 1;
        await setNextAvailableCounter(effectiveCounter + 1);
      } else {
        // Normal case - use our local counter and increment for next time
        effectiveCounter = _nextAvailableCounter;
        await increment();
      }

      return VectorClock({
        ...?previous?.vclock,
        _host: effectiveCounter,
      });
    } finally {
      _lock = null;
      completer.complete();
    }
  }
}
