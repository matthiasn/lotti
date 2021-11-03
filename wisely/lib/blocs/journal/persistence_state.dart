import 'package:freezed_annotation/freezed_annotation.dart';

part 'persistence_state.freezed.dart';

@freezed
class PersistenceState with _$PersistenceState {
  factory PersistenceState.initial() = _Initial;
  factory PersistenceState.loading() = _Loading;
  factory PersistenceState.online() = _Online;
  factory PersistenceState.failed() = _Failed;
}
