import 'package:freezed_annotation/freezed_annotation.dart';

part 'vector_clock_state.freezed.dart';
part 'vector_clock_state.g.dart';

@freezed
class VectorClockCounterState with _$VectorClockCounterState {
  factory VectorClockCounterState(
      {required String host,
      required int nextAvailableCounter}) = _VectorClockCounterState;

  factory VectorClockCounterState.fromJson(Map<String, dynamic> json) =>
      _$VectorClockCounterStateFromJson(json);

  factory VectorClockCounterState.next(VectorClockCounterState state) =>
      state.copyWith(nextAvailableCounter: state.nextAvailableCounter + 1);
}
