import 'package:freezed_annotation/freezed_annotation.dart';

part 'outbox_state.freezed.dart';

@freezed
class OutboxState with _$OutboxState {
  factory OutboxState.initial() = _Initial;
  factory OutboxState.loading() = _Loading;
  factory OutboxState.online() = _Online;
  factory OutboxState.disabled() = OutboxDisabled;
  factory OutboxState.failed() = _Failed;
}

enum OutboxStatus {
  pending,
  sent,
  error,
}
