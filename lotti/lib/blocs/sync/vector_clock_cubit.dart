import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();
const String hostKey = 'VC_HOST';
const String nextAvailableCounterKey = 'VC_NEXT_AVAILABLE_COUNTER';

class VectorClockCubit extends Cubit<void> {
  VectorClockCubit() : super(null);

  Future<void> increment() async {
    int next = await getNextAvailableCounter() + 1;
    setNextAvailableCounter(next);
  }

  Future<String> getHost() async {
    String? host = await SecureStorage.readValue(hostKey);

    if (host == null) {
      host = uuid.v4();
      SecureStorage.writeValue(hostKey, host);
    }
    return host;
  }

  Future<void> setNextAvailableCounter(int nextAvailableCounter) async {
    SecureStorage.writeValue(
      nextAvailableCounterKey,
      nextAvailableCounter.toString(),
    );
  }

  Future<int> getNextAvailableCounter() async {
    int? nextAvailableCounter;
    String? nextAvailableCounterString =
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
    var bytes = utf8.encode(await getHost());
    var digest = sha1.convert(bytes);
    return digest.toString();
  }

  // TODO: only increment after successful insertion
  Future<VectorClock> getNextVectorClock({VectorClock? previous}) async {
    String host = await getHost();
    int nextAvailableCounter = await getNextAvailableCounter();
    increment();

    return VectorClock({
      ...?previous?.vclock,
      host: nextAvailableCounter,
    });
  }
}
