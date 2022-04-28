import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

part 'bp_chart_info_cubit.freezed.dart';

class BpChartInfoCubit extends Cubit<BpChartInfoState> {
  BpChartInfoCubit()
      : super(
          BpChartInfoState(
            systolic: null,
            diastolic: null,
          ),
        );

  void setSelected({
    Observation? systolic,
    Observation? diastolic,
  }) {
    emit(
      BpChartInfoState(
        systolic: systolic,
        diastolic: diastolic,
      ),
    );
  }

  void clearSelected() {
    emit(
      BpChartInfoState(
        systolic: null,
        diastolic: null,
      ),
    );
  }
}

@freezed
class BpChartInfoState with _$BpChartInfoState {
  factory BpChartInfoState({
    required Observation? systolic,
    required Observation? diastolic,
  }) = _BpChartInfoState;
}
