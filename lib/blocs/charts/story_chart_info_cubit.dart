import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/logic/charts/story_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

part 'story_chart_info_cubit.freezed.dart';

class StoryChartInfoCubit extends Cubit<StoryChartInfoState> {
  StoryChartInfoCubit() : super(StoryChartInfoState(selected: null));

  void setSelected(Observation? observation) {
    emit(StoryChartInfoState(selected: observation));
  }

  void clearSelected() {
    emit(StoryChartInfoState(selected: null));
  }
}

@freezed
class StoryChartInfoState with _$StoryChartInfoState {
  factory StoryChartInfoState({
    required Observation? selected,
  }) = _StoryChartInfoState;
}

class WeeklyStoryChartInfoCubit extends Cubit<WeeklyStoryChartInfoState> {
  WeeklyStoryChartInfoCubit()
      : super(WeeklyStoryChartInfoState(selected: null));

  void setSelected(WeeklyAggregate? observation) {
    emit(WeeklyStoryChartInfoState(selected: observation));
  }

  void clearSelected() {
    emit(WeeklyStoryChartInfoState(selected: null));
  }
}

@freezed
class WeeklyStoryChartInfoState with _$WeeklyStoryChartInfoState {
  factory WeeklyStoryChartInfoState({
    required WeeklyAggregate? selected,
  }) = _WeeklyStoryChartInfoState;
}
