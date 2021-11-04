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

  VectorClock getNextVectorClock() {
    String host = state.host;
    int nextAvailableCounter = state.nextAvailableCounter;
    increment();
    return VectorClock(<String, int>{host: nextAvailableCounter});
  }

  @override
  VectorClockCounterState fromJson(Map<String, dynamic> json) =>
      VectorClockCounterState.fromJson(json);

  @override
  Map<String, dynamic> toJson(VectorClockCounterState state) => state.toJson();
}
