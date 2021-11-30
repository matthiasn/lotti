import 'package:freezed_annotation/freezed_annotation.dart';

part 'outbound_queue_state.freezed.dart';

@freezed
class OutboundQueueState with _$OutboundQueueState {
  factory OutboundQueueState.initial() = _Initial;
  factory OutboundQueueState.loading() = _Loading;
  factory OutboundQueueState.online() = _Online;
  factory OutboundQueueState.failed() = _Failed;
}

enum OutboundMessageStatus { pending, sent, error }

class OutboundQueueRecord {
  final int? id;
  final String message;
  final OutboundMessageStatus status;
  final int retries;
  final String subject;
  final String? filePath;
  final DateTime createdAt;
  DateTime? updatedAt;

  OutboundQueueRecord({
    this.id,
    required this.message,
    required this.subject,
    required this.status,
    required this.retries,
    required this.createdAt,
    this.filePath,
    this.updatedAt,
  });

  @override
  String toString() {
    return '$id $status $subject $createdAt $updatedAt';
  }

  factory OutboundQueueRecord.fromMap(Map<String, dynamic> data) =>
      OutboundQueueRecord(
        id: data['id'],
        message: data['message'],
        filePath: data['file_path'],
        status: OutboundMessageStatus.values[data['status']],
        retries: data['retries'],
        subject: data['subject'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at']),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at']),
      );

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'status': status.index,
      'retries': retries,
      'message': message,
      'file_path': filePath,
      'subject': subject,
    };
  }
}
