import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';

const String hostKey = 'VC_HOST';
const String nextAvailableCounterKey = 'VC_NEXT_AVAILABLE_COUNTER';

class VectorClockService {
  Future<void> increment() async {
    final next = await getNextAvailableCounter() + 1;
    await setNextAvailableCounter(next);
  }

  Future<String> setNewHost() async {
    final host = uuid.v4();
    await SecureStorage.writeValue(hostKey, host);
    return host;
  }

  Future<String> getHost() async {
    var host = await SecureStorage.readValue(hostKey);
    // ignore: join_return_with_assignment
    host ??= await setNewHost();
    return host;
  }

  Future<void> setNextAvailableCounter(int nextAvailableCounter) async {
    await SecureStorage.writeValue(
      nextAvailableCounterKey,
      nextAvailableCounter.toString(),
    );
  }

  Future<int> getNextAvailableCounter() async {
    int? nextAvailableCounter;
    final nextAvailableCounterString =
        await SecureStorage.readValue(nextAvailableCounterKey);

    if (nextAvailableCounterString != null) {
      nextAvailableCounter = int.parse(nextAvailableCounterString);
    } else {
      nextAvailableCounter = 0;
      await setNextAvailableCounter(nextAvailableCounter);
    }
    return nextAvailableCounter;
  }

  Future<String> getHostHash() async {
    final bytes = utf8.encode(await getHost());
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  // ignore: flutter_style_todos
  // TODO: only increment after successful insertion
  Future<VectorClock> getNextVectorClock({VectorClock? previous}) async {
    final host = await getHost();
    final nextAvailableCounter = await getNextAvailableCounter();
    await increment();

    return VectorClock({
      ...?previous?.vclock,
      host: nextAvailableCounter,
    });
  }
}
