import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/secure_storage.dart';
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
    _host = await getHost() ?? await setNewHost();
    _nextAvailableCounter = await _getNextAvailableCounter();
  }

  Future<void> increment() async {
    final next = await getNextAvailableCounter() + 1;
    await setNextAvailableCounter(next);
  }

  Future<String> setNewHost() async {
    final host = uuid.v4();
    await getIt<SecureStorage>().writeValue(hostKey, host);
    return host;
  }

  Future<String?> getHost() async {
    return getIt<SecureStorage>().readValue(hostKey);
  }

  Future<void> setNextAvailableCounter(int nextAvailableCounter) async {
    await getIt<SecureStorage>().writeValue(
      nextAvailableCounterKey,
      nextAvailableCounter.toString(),
    );
    _nextAvailableCounter = nextAvailableCounter;
  }

  Future<int> _getNextAvailableCounter() async {
    int? nextAvailableCounter;
    final nextAvailableCounterString =
        await getIt<SecureStorage>().readValue(nextAvailableCounterKey);

    if (nextAvailableCounterString != null) {
      nextAvailableCounter = int.parse(nextAvailableCounterString);
    } else {
      nextAvailableCounter = 0;
      await setNextAvailableCounter(nextAvailableCounter);
    }
    return nextAvailableCounter;
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
