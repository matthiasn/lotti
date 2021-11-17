import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/blocs/sync/vector_clock_state.dart';
import 'package:wisely/sync/vector_clock.dart';

const uuid = Uuid();

class VectorClockCubit extends HydratedCubit<VectorClockCounterState> {
  VectorClockCubit()
      : super(
            VectorClockCounterState(host: uuid.v4(), nextAvailableCounter: 0));

  void increment() {
    emit(VectorClockCounterState.next(state));
  }

  String getHost() {
    return state.host;
  }

  String getHostHash() {
    var bytes = utf8.encode(state.host);
    var digest = sha1.convert(bytes);
    return digest.toString();
  }

  // TODO: only increment after successful insertion
  VectorClock getNextVectorClock({VectorClock? previous}) {
    String host = state.host;
    int nextAvailableCounter = state.nextAvailableCounter;
    increment();

    return VectorClock({
      ...?previous?.vclock,
      host: nextAvailableCounter,
    });
  }

  @override
  VectorClockCounterState fromJson(Map<String, dynamic> json) =>
      VectorClockCounterState.fromJson(json);

  @override
  Map<String, dynamic> toJson(VectorClockCounterState state) => state.toJson();
}
