import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/wake_conversation_trace.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  ChatCompletionMessageToolCall call(String name) =>
      ChatCompletionMessageToolCall(
        id: 'call-$name',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: name,
          arguments: '{"secret":"user words"}',
        ),
      );

  const system = ChatCompletionMessage.system(content: 'scaffold');
  const user = ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.string('task context'),
  );

  test('a prose reply on the first turn reads as [text]', () {
    expect(
      wakeConversationTrace([
        system,
        user,
        const ChatCompletionMessage.assistant(content: 'Nothing changed.'),
      ]),
      '[text]',
    );
  });

  test('lists each turn in order, ending on the closing reply', () {
    expect(
      wakeConversationTrace([
        system,
        user,
        ChatCompletionMessage.assistant(
          toolCalls: [call('set_task_estimate'), call('record_observations')],
        ),
        const ChatCompletionMessage.tool(toolCallId: 'a', content: 'ok'),
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Continue.'),
        ),
        ChatCompletionMessage.assistant(toolCalls: [call('update_report')]),
      ]),
      '[set_task_estimate,record_observations] → [update_report]',
    );
  });

  test('an empty tool-call list is a text reply, not an empty bracket', () {
    expect(
      wakeConversationTrace([
        const ChatCompletionMessage.assistant(content: 'Done.', toolCalls: []),
      ]),
      '[text]',
    );
  });

  test('names a conversation the model never answered', () {
    expect(wakeConversationTrace([system, user]), 'no reply');
  });

  test('carries tool names only, never arguments or reply text', () {
    final trace = wakeConversationTrace([
      ChatCompletionMessage.assistant(
        content: 'private reasoning',
        toolCalls: [call('record_observations')],
      ),
    ]);
    expect(trace, isNot(contains('user words')));
    expect(trace, isNot(contains('private reasoning')));
  });
}
