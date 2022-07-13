import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/widgets/charts/utils.dart';

part 'story_chart_info_cubit.freezed.dart';

class StoryChartInfoCubit extends Cubit<StoryChartInfoState> {
  StoryChartInfoCubit() : super(StoryChartInfoState(selected: null));

  void setSelected(MeasuredObservation? observation) {
    emit(StoryChartInfoState(selected: observation));
  }

  void clearSelected() {
    emit(StoryChartInfoState(selected: null));
  }
}

@freezed
class StoryChartInfoState with _$StoryChartInfoState {
  factory StoryChartInfoState({
    required MeasuredObservation? selected,
  }) = _StoryChartInfoState;
}
