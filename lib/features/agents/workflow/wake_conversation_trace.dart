import 'package:openai_dart/openai_dart.dart';

/// The tool calls of each assistant turn in [messages], for a wake's log line.
///
/// One bracket per turn, holding the tool names that turn called, or `text`
/// for a reply with no tool call — the reply that ends a wake. So `[text]` is
/// a wake that answered in prose on its first turn and changed nothing, and a
/// trace that ends on tool names stopped while the model was still calling
/// tools (after `update_report`, or at the turn limit). `no reply` means the
/// model never answered. Tool names only: no arguments, no text.
String wakeConversationTrace(Iterable<ChatCompletionMessage> messages) {
  final turns = [
    for (final message in messages)
      ?message.mapOrNull(
        assistant: (assistant) {
          final names = [
            for (final call
                in assistant.toolCalls ??
                    const <ChatCompletionMessageToolCall>[])
              call.function.name,
          ];
          return '[${names.isEmpty ? 'text' : names.join(',')}]';
        },
      ),
  ];
  return turns.isEmpty ? 'no reply' : turns.join(' → ');
}
