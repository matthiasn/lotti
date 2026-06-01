import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    glados.Glados(
      glados.any.generatedThoughtSignatureScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated last-write-wins signature model', (scenario) {
      final collector = ThoughtSignatureCollector();
      for (final operation in scenario.operations) {
        collector.addSignature(operation.toolCallId, operation.signature);
      }

      expect(collector.hasSignatures, scenario.expected.isNotEmpty);
      expect(collector.signatures, scenario.expected, reason: '$scenario');
      expect(
        () => collector.signatures['new_key'] = 'value',
        throwsA(isA<UnsupportedError>()),
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
}

enum _GeneratedToolCallId { empty, tool0, tool1, shared, slash }

enum _GeneratedThoughtSignature {
  empty,
  base64,
  updated,
  punctuation,
  multiline,
}

class _GeneratedThoughtSignatureOperation {
  const _GeneratedThoughtSignatureOperation({
    required this.toolCallId,
    required this.signature,
  });

  final String toolCallId;
  final String signature;

  @override
  String toString() {
    return '_GeneratedThoughtSignatureOperation('
        'toolCallId: "$toolCallId", '
        'signature: "$signature")';
  }
}

class _GeneratedThoughtSignatureScenario {
  const _GeneratedThoughtSignatureScenario(this.operations);

  final List<_GeneratedThoughtSignatureOperation> operations;

  Map<String, String> get expected {
    final result = <String, String>{};
    for (final operation in operations) {
      result[operation.toolCallId] = operation.signature;
    }
    return result;
  }

  @override
  String toString() =>
      '_GeneratedThoughtSignatureScenario(operations: $operations)';
}

extension on _GeneratedToolCallId {
  String get value => switch (this) {
    _GeneratedToolCallId.empty => '',
    _GeneratedToolCallId.tool0 => 'tool_0',
    _GeneratedToolCallId.tool1 => 'tool_1',
    _GeneratedToolCallId.shared => 'shared',
    _GeneratedToolCallId.slash => 'tool/with/slash',
  };
}

extension on _GeneratedThoughtSignature {
  String get value => switch (this) {
    _GeneratedThoughtSignature.empty => '',
    _GeneratedThoughtSignature.base64 => 'base64+encoded/signature==',
    _GeneratedThoughtSignature.updated => 'updated-signature',
    _GeneratedThoughtSignature.punctuation => r'!@#$%^&*()',
    _GeneratedThoughtSignature.multiline => 'line1\nline2',
  };
}

extension _AnyThoughtSignatureCollector on glados.Any {
  glados.Generator<_GeneratedToolCallId> get _toolCallId =>
      glados.AnyUtils(this).choose(_GeneratedToolCallId.values);

  glados.Generator<_GeneratedThoughtSignature> get _thoughtSignature =>
      glados.AnyUtils(this).choose(_GeneratedThoughtSignature.values);

  glados.Generator<_GeneratedThoughtSignatureOperation> get _operation =>
      glados.CombinableAny(this).combine2(
        _toolCallId,
        _thoughtSignature,
        (
          _GeneratedToolCallId toolCallId,
          _GeneratedThoughtSignature signature,
        ) => _GeneratedThoughtSignatureOperation(
          toolCallId: toolCallId.value,
          signature: signature.value,
        ),
      );

  glados.Generator<_GeneratedThoughtSignatureScenario>
  get generatedThoughtSignatureScenario => glados.ListAnys(this)
      .listWithLengthInRange(0, 20, _operation)
      .map(_GeneratedThoughtSignatureScenario.new);
}
