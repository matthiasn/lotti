import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/sync_message.dart';

part 'outbound_queue_state.freezed.dart';

@freezed
class OutboundQueueState with _$OutboundQueueState {
  factory OutboundQueueState.initial() = _Initial;
  factory OutboundQueueState.loading() = _Loading;
  factory OutboundQueueState.online() = _Online;
  factory OutboundQueueState.failed() = _Failed;
}

class OutboundQueueRecord {
  final int? id;
  final String encryptedMessage;
  final OutboundMessageStatus status;
  final String subject;
  final DateTime createdAt;
  DateTime? updatedAt;

  OutboundQueueRecord({
    this.id,
    required this.encryptedMessage,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OutboundQueueRecord.fromMap(Map<String, dynamic> data) =>
      OutboundQueueRecord(
          id: data['id'],
          encryptedMessage: data['message'],
          status: data['status'],
          subject: data['subject'],
          createdAt: data['created_at'],
          updatedAt: data['updated_at']);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'status': OutboundMessageStatus.sent.index,
      'message': encryptedMessage,
      'subject': subject,
    };
  }
}
