import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference.dart';

void main() {
  group('role', () {
    test('each variant reports its own role', () {
      expect(const LottiMessage.system('x').role, LottiMessageRole.system);
      expect(
        const LottiMessage.developer('x').role,
        LottiMessageRole.developer,
      );
      expect(LottiMessage.userText('x').role, LottiMessageRole.user);
      expect(
        const LottiMessage.assistant(content: 'x').role,
        LottiMessageRole.assistant,
      );
      expect(
        const LottiMessage.tool(toolCallId: 'c', content: 'x').role,
        LottiMessageRole.tool,
      );
    });
  });

  group('textContent', () {
    test('returns the text of every role', () {
      expect(const LottiMessage.system('sys').textContent, 'sys');
      expect(const LottiMessage.developer('dev').textContent, 'dev');
      expect(LottiMessage.userText('usr').textContent, 'usr');
      expect(
        const LottiMessage.assistant(content: 'ast').textContent,
        'ast',
      );
      expect(
        const LottiMessage.tool(toolCallId: 'c', content: 'tool').textContent,
        'tool',
      );
    });

    test('is null for an assistant turn that only called tools', () {
      // Callers looking for "the model's last words" must skip these rather
      // than treat them as an empty answer.
      const message = LottiMessage.assistant(
        toolCalls: [LottiToolCall(id: 'c', name: 'n', arguments: '{}')],
      );
      expect(message.textContent, isNull);
    });

    test('joins the text parts of a multimodal user turn, skipping others', () {
      final message = LottiMessage.userParts(const [
        LottiContentPart.text('a'),
        LottiContentPart.image('data:image/png;base64,x'),
        LottiContentPart.text('b'),
      ]);
      expect(message.textContent, 'a\nb');
    });
  });

  group('role-scoped accessors', () {
    test('each returns a value only for its own role', () {
      final user = LottiMessage.userText('u');
      const assistant = LottiMessage.assistant(content: 'a');
      const tool = LottiMessage.tool(toolCallId: 'c', content: 't');

      expect(user.userContent, 'u');
      expect(user.assistantContent, isNull);
      expect(user.toolContent, isNull);

      expect(assistant.assistantContent, 'a');
      expect(assistant.userContent, isNull);
      expect(assistant.toolContent, isNull);

      expect(tool.toolContent, 't');
      expect(tool.userContent, isNull);
      expect(tool.assistantContent, isNull);
    });

    test('assistantToolCalls exposes the calls only on an assistant turn', () {
      const calls = [LottiToolCall(id: 'c', name: 'n', arguments: '{}')];
      expect(
        const LottiMessage.assistant(toolCalls: calls).assistantToolCalls,
        calls,
      );
      expect(LottiMessage.userText('u').assistantToolCalls, isNull);
    });
  });

  group('equality', () {
    test('distinguishes roles carrying identical text', () {
      // Test assertions compare whole conversations, so a system and a
      // developer message with the same words must not collapse.
      expect(
        const LottiMessage.system('same'),
        isNot(const LottiMessage.developer('same')),
      );
    });

    test('compares user content structurally, not by identity', () {
      expect(LottiMessage.userText('hi'), LottiMessage.userText('hi'));
      expect(
        LottiMessage.userParts(const [LottiContentPart.text('hi')]),
        LottiMessage.userParts(const [LottiContentPart.text('hi')]),
      );
      // A bare string and a one-element parts array serialize differently,
      // so they are not equal either.
      expect(
        LottiMessage.userText('hi'),
        isNot(LottiMessage.userParts(const [LottiContentPart.text('hi')])),
      );
    });

    test('compares assistant tool calls element-wise', () {
      const a = LottiMessage.assistant(
        toolCalls: [LottiToolCall(id: 'c', name: 'n', arguments: '{}')],
      );
      const b = LottiMessage.assistant(
        toolCalls: [LottiToolCall(id: 'c', name: 'n', arguments: '{}')],
      );
      const c = LottiMessage.assistant(
        toolCalls: [LottiToolCall(id: 'c', name: 'n', arguments: '{"a":1}')],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('LottiToolCall', () {
    test('copyWith replaces only the named fields', () {
      const call = LottiToolCall(id: 'c', name: 'n', arguments: '{}');
      expect(
        call.copyWith(arguments: '{"a":1}'),
        const LottiToolCall(id: 'c', name: 'n', arguments: '{"a":1}'),
      );
      expect(call.copyWith(), call);
    });
  });
}
