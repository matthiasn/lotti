import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';

void main() {
  group('GeminiToolCall', () {
    test('creates instance with all required parameters', () {
      const toolCall = GeminiToolCall(
        name: 'test_function',
        arguments: '{"key": "value"}',
        id: 'tool_0',
      );

      expect(toolCall.name, 'test_function');
      expect(toolCall.arguments, '{"key": "value"}');
      expect(toolCall.id, 'tool_0');
      expect(toolCall.thoughtSignature, isNull);
    });

    test('creates instance with optional thoughtSignature', () {
      const toolCall = GeminiToolCall(
        name: 'test_function',
        arguments: '{}',
        id: 'tool_1',
        thoughtSignature: 'sig-abc123',
      );

      expect(toolCall.name, 'test_function');
      expect(toolCall.arguments, '{}');
      expect(toolCall.id, 'tool_1');
      expect(toolCall.thoughtSignature, 'sig-abc123');
    });

    test('toString shows hasSignature=false when no signature', () {
      const toolCall = GeminiToolCall(
        name: 'my_func',
        arguments: '{}',
        id: 'call_0',
      );

      expect(
        toolCall.toString(),
        'GeminiToolCall(name: my_func, id: call_0, hasSignature: false)',
      );
    });

    test('toString shows hasSignature=true when signature present', () {
      const toolCall = GeminiToolCall(
        name: 'my_func',
        arguments: '{"x": 1}',
        id: 'call_1',
        thoughtSignature: 'signature-value',
      );

      expect(
        toolCall.toString(),
        'GeminiToolCall(name: my_func, id: call_1, hasSignature: true)',
      );
    });

    test('can be created as const', () {
      const toolCall1 = GeminiToolCall(
        name: 'func',
        arguments: '{}',
        id: 'id_0',
      );
      const toolCall2 = GeminiToolCall(
        name: 'func',
        arguments: '{}',
        id: 'id_0',
      );

      // Same const values should be identical
      expect(identical(toolCall1, toolCall2), isTrue);
    });
  });

  group('ThoughtSignatureCollector', () {
    late ThoughtSignatureCollector collector;

    setUp(() {
      collector = ThoughtSignatureCollector();
    });

    test('initially has no signatures', () {
      expect(collector.hasSignatures, isFalse);
      expect(collector.signatures, isEmpty);
    });

    test('addSignature stores signature by toolCallId', () {
      collector.addSignature('tool_0', 'sig-xyz');

      expect(collector.hasSignatures, isTrue);
      expect(collector.signatures, {'tool_0': 'sig-xyz'});
    });

    test('getSignature returns signature for existing id', () {
      collector.addSignature('tool_0', 'sig-123');

      expect(collector.getSignature('tool_0'), 'sig-123');
    });

    test('getSignature returns null for non-existent id', () {
      collector.addSignature('tool_0', 'sig-123');

      expect(collector.getSignature('tool_1'), isNull);
    });

    test('addSignature overwrites existing signature for same id', () {
      collector
        ..addSignature('tool_0', 'first-sig')
        ..addSignature('tool_0', 'second-sig');

      expect(collector.getSignature('tool_0'), 'second-sig');
      expect(collector.signatures.length, 1);
    });

    test('supports multiple signatures', () {
      collector
        ..addSignature('tool_0', 'sig-0')
        ..addSignature('tool_1', 'sig-1')
        ..addSignature('tool_2', 'sig-2');

      expect(collector.signatures.length, 3);
      expect(collector.getSignature('tool_0'), 'sig-0');
      expect(collector.getSignature('tool_1'), 'sig-1');
      expect(collector.getSignature('tool_2'), 'sig-2');
    });

    test('signatures returns unmodifiable map', () {
      collector.addSignature('tool_0', 'sig-0');

      final sigs = collector.signatures;

      // Verify it's unmodifiable
      expect(
        () => sigs['new_key'] = 'value',
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('clear removes all signatures', () {
      collector
        ..addSignature('tool_0', 'sig-0')
        ..addSignature('tool_1', 'sig-1');

      expect(collector.hasSignatures, isTrue);

      collector.clear();

      expect(collector.hasSignatures, isFalse);
      expect(collector.signatures, isEmpty);
      expect(collector.getSignature('tool_0'), isNull);
    });

    test('hasSignatures returns false after clear', () {
      collector.addSignature('tool_0', 'sig');
      expect(collector.hasSignatures, isTrue);

      collector.clear();
      expect(collector.hasSignatures, isFalse);
    });

    test('can add signatures after clear', () {
      collector
        ..addSignature('tool_0', 'old-sig')
        ..clear()
        ..addSignature('tool_1', 'new-sig');

      expect(collector.hasSignatures, isTrue);
      expect(collector.getSignature('tool_0'), isNull);
      expect(collector.getSignature('tool_1'), 'new-sig');
    });

    test('handles empty string signatures', () {
      collector.addSignature('tool_0', '');

      expect(collector.hasSignatures, isTrue);
      expect(collector.getSignature('tool_0'), '');
    });

    test('handles signatures with special characters', () {
      const signature = 'base64+encoded/signature==';
      collector.addSignature('tool_0', signature);

      expect(collector.getSignature('tool_0'), signature);
    });
  });
}
