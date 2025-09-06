/// Custom exceptions for AI chat functionality
abstract class ChatException implements Exception {
  const ChatException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ChatException: $message';
}

/// Exception thrown when sending a message fails
class ChatRepositoryException extends ChatException {
  const ChatRepositoryException(super.message, [super.cause]);

  @override
  String toString() => 'ChatRepositoryException: $message';
}

/// Exception thrown when processing AI responses fails
class ChatProcessingException extends ChatException {
  const ChatProcessingException(super.message, [super.cause]);

  @override
  String toString() => 'ChatProcessingException: $message';
}

/// Exception thrown when tool calls fail
class ChatToolException extends ChatException {
  const ChatToolException(super.message, [super.cause]);

  @override
  String toString() => 'ChatToolException: $message';
}
