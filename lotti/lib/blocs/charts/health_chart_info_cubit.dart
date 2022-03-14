import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

part 'health_chart_info_cubit.freezed.dart';

class HealthChartInfoCubit extends Cubit<HealthChartInfoState> {
  HealthChartInfoCubit() : super(HealthChartInfoState(selected: null));

  void setSelected(Observation? observation) {
    emit(HealthChartInfoState(selected: observation));
  }

  void clearSelected() {
    emit(HealthChartInfoState(selected: null));
  }
}

@freezed
class HealthChartInfoState with _$HealthChartInfoState {
  factory HealthChartInfoState({
    required Observation? selected,
  }) = _HealthChartInfoState;
}
