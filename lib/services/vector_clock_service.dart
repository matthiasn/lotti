import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/utils.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';

class VectorClockService {
  VectorClockService() {
    init();
  }
  late int _nextAvailableCounter;
  late String _host;

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

    await getIt<SettingsDb>().saveSettingsItem(
      SettingsItem(
        configKey: hostKey,
        value: host,
        updatedAt: DateTime.now(),
      ),
    );

    await setNextAvailableCounter(0);

    _host = host;
    return host;
  }

  Future<String?> _getHost() async {
    final existing =
        await getIt<SettingsDb>().watchSettingsItemByKey(hostKey).first;

    if (existing.isNotEmpty) {
      return existing.first.value;
    }

    return null;
  }

  Future<String?> getHost() async {
    return _host;
  }

  Future<void> setNextAvailableCounter(int nextAvailableCounter) async {
    _nextAvailableCounter = nextAvailableCounter;

    await getIt<SettingsDb>().saveSettingsItem(
      SettingsItem(
        configKey: nextAvailableCounterKey,
        value: nextAvailableCounter.toString(),
        updatedAt: DateTime.now(),
      ),
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

  // ignore: flutter_style_todos
  // TODO: only increment after successful insertion
  Future<VectorClock> getNextVectorClock({VectorClock? previous}) async {
    final nextAvailableCounter = _nextAvailableCounter;
    await increment();

    return VectorClock({
      ...?previous?.vclock,
      _host: nextAvailableCounter,
    });
  }
}
