import 'package:freezed_annotation/freezed_annotation.dart';

part 'outbound_queue_state.freezed.dart';

@freezed
class OutboundQueueState with _$OutboundQueueState {
  factory OutboundQueueState.initial() = _Initial;
  factory OutboundQueueState.loading() = _Loading;
  factory OutboundQueueState.online() = _Online;
  factory OutboundQueueState.failed() = _Failed;
}
