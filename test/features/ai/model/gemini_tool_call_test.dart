import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';

void main() {
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

    test('addSignature overwrites existing signature for same id', () {
      collector
        ..addSignature('tool_0', 'first-sig')
        ..addSignature('tool_0', 'second-sig');

      expect(collector.signatures['tool_0'], 'second-sig');
      expect(collector.signatures.length, 1);
    });

    test('supports multiple signatures', () {
      collector
        ..addSignature('tool_0', 'sig-0')
        ..addSignature('tool_1', 'sig-1')
        ..addSignature('tool_2', 'sig-2');

      expect(collector.signatures.length, 3);
      expect(collector.signatures['tool_0'], 'sig-0');
      expect(collector.signatures['tool_1'], 'sig-1');
      expect(collector.signatures['tool_2'], 'sig-2');
    });

    test('signatures returns unmodifiable map', () {
      collector.addSignature('tool_0', 'sig-0');

      final sigs = collector.signatures;

      expect(
        () => sigs['new_key'] = 'value',
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('handles empty string signatures', () {
      collector.addSignature('tool_0', '');

      expect(collector.hasSignatures, isTrue);
      expect(collector.signatures['tool_0'], '');
    });

    test('handles signatures with special characters', () {
      const signature = 'base64+encoded/signature==';
      collector.addSignature('tool_0', signature);

      expect(collector.signatures['tool_0'], signature);
    });
  });
}
