import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/widgets/charts/utils.dart';

part 'measurables_chart_info_cubit.freezed.dart';

class MeasurablesChartInfoCubit extends Cubit<MeasurablesChartInfoState> {
  MeasurablesChartInfoCubit()
      : super(MeasurablesChartInfoState(selected: null));

  void setSelected(MeasuredObservation? observation) {
    emit(MeasurablesChartInfoState(selected: observation));
  }

  void clearSelected() {
    emit(MeasurablesChartInfoState(selected: null));
  }
}

@freezed
class MeasurablesChartInfoState with _$MeasurablesChartInfoState {
  factory MeasurablesChartInfoState({
    required MeasuredObservation? selected,
  }) = _MeasurablesChartInfoState;
}
