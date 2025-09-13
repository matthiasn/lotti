import 'package:freezed_annotation/freezed_annotation.dart';

part 'outbox_state.freezed.dart';

@freezed
sealed class OutboxState with _$OutboxState {
  factory OutboxState.initial() = _Initial;
  factory OutboxState.online() = _Online;
  factory OutboxState.disabled() = OutboxDisabled;
}

enum OutboxStatus {
  pending,
  sent,
  error,
}
