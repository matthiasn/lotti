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
