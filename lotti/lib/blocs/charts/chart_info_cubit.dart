import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

part 'chart_info_cubit.freezed.dart';

class ChartInfoCubit extends Cubit<ChartInfoState> {
  ChartInfoCubit() : super(ChartInfoState(selected: null)) {}

  Future<void> toggleSelected(Observation? observation) async {
    if (state.selected?.dateTime == observation?.dateTime) {
      emit(ChartInfoState(selected: null));
    } else {
      emit(ChartInfoState(selected: observation));
    }
  }
}

@freezed
class ChartInfoState with _$ChartInfoState {
  factory ChartInfoState({
    required Observation? selected,
  }) = _ChartInfoState;
}
