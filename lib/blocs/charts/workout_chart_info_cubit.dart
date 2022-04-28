import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

part 'workout_chart_info_cubit.freezed.dart';

class WorkoutChartInfoCubit extends Cubit<WorkoutChartInfoState> {
  WorkoutChartInfoCubit() : super(WorkoutChartInfoState(selected: null));

  void setSelected(Observation? observation) {
    emit(WorkoutChartInfoState(selected: observation));
  }

  void clearSelected() {
    emit(WorkoutChartInfoState(selected: null));
  }
}

@freezed
class WorkoutChartInfoState with _$WorkoutChartInfoState {
  factory WorkoutChartInfoState({
    required Observation? selected,
  }) = _WorkoutChartInfoState;
}
