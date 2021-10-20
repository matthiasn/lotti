import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'vector_clock_counter_cubit.g.dart';

const uuid = Uuid();

@JsonSerializable()
class VectorClockCubitState extends Equatable {
  late final String host;
  late final int nextAvailableCounter;

  VectorClockCubitState(
      {required this.host, required this.nextAvailableCounter});

  VectorClockCubitState.next(VectorClockCubitState state) {
    host = state.host;
    nextAvailableCounter = state.nextAvailableCounter + 1;
  }

  factory VectorClockCubitState.fromJson(Map<String, dynamic> json) =>
      _$VectorClockCubitStateFromJson(json);

  Map<String, dynamic> toJson() => _$VectorClockCubitStateToJson(this);

  @override
  List<Object?> get props => [host, nextAvailableCounter];

  @override
  String toString() {
    return 'VectorClockCubitState host: $host, nextAvailableCounter: $nextAvailableCounter';
  }
}

class VectorClockCubit extends HydratedCubit<VectorClockCubitState> {
  VectorClockCubit()
      : super(VectorClockCubitState(host: uuid.v4(), nextAvailableCounter: 0));

  void increment() {
    VectorClockCubitState next = VectorClockCubitState.next(state);
    print(next);
    emit(next);
  }

  @override
  VectorClockCubitState fromJson(Map<String, dynamic> json) =>
      VectorClockCubitState.fromJson(json);

  @override
  Map<String, dynamic> toJson(VectorClockCubitState state) => state.toJson();
}
