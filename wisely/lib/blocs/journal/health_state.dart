import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_state.freezed.dart';

@freezed
class HealthState with _$HealthState {
  factory HealthState() = _Initial;
}
