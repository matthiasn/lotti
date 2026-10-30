part of 'matrix_payload_sender.dart';

/// Upload of embedding-vectors attachments for [MatrixPayloadSender]
/// (ADR 0150). Public for the same reason as
/// [MatrixPayloadSenderNotifications]: [MatrixMessageSender] in a sibling
/// library calls it.
///
/// Each version has a file of its own, written when it was enqueued and
/// deleted once its message is sent ([discardEmbeddingVectorsFile]).
extension MatrixPayloadSenderEmbeddingVectors on MatrixPayloadSender {
  /// Uploads the attachment of [message] and returns the message pointing
  /// at it; `null` when the upload failed, so the row is retried.
  ///
  /// A tombstone has nothing to upload. A version whose file is gone is sent
  /// without one: either an exact copy has already gone out and deleted it,
  /// or a newer version of the register replaced it before this one was
  /// sent. Either way the receiver needs only the receipt.
  Future<SyncEmbeddingVectors?> sendEmbeddingVectorsPayload({
    required Room room,
    required SyncEmbeddingVectors message,
  }) async {
    final jsonPath = message.jsonPath;
    if (message.deleted || jsonPath == null) return message;

    final file = _embeddingVectorsFile(jsonPath);
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException {
      _trace(
        'embeddingVectors.fileGone path=$jsonPath id=${message.id}',
        subDomain: 'matrix.send',
      );
      return message.copyWith(jsonPath: null, attachmentEventId: null);
    }

    final upload = await _sendFile(
      room: room,
      fullPath: file.path,
      relativePath: jsonPath,
      bytes: bytes,
    );
    final attachmentEventId = upload.eventId;
    if (!upload.succeeded || attachmentEventId == null) return null;
    return message.copyWith(attachmentEventId: attachmentEventId);
  }

  /// Deletes the attachment file of [message] once it is sent. Best effort:
  /// a file left behind is replaced by the register's next version.
  Future<void> discardEmbeddingVectorsFile(SyncEmbeddingVectors message) async {
    final jsonPath = message.jsonPath;
    if (jsonPath == null) return;
    try {
      await _embeddingVectorsFile(jsonPath).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  File _embeddingVectorsFile(String jsonPath) => File(
    p.join(
      documentsDirectory.path,
      p.joinAll(jsonPath.split('/').where((part) => part.isNotEmpty)),
    ),
  );
}
