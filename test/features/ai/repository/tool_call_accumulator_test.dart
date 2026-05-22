import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show
        Any,
        AnyUtils,
        CombinableAny,
        Generator,
        Glados,
        IntAnys,
        ListAnys,
        any;
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/repository/tool_call_accumulator.dart';

class _GeneratedToolCallStream {
  const _GeneratedToolCallStream({
    required this.argumentPartValuesByCall,
  });

  final List<List<int>> argumentPartValuesByCall;

  int get callCount => argumentPartValuesByCall.length;

  int get maxPartCount => argumentPartValuesByCall.fold<int>(
    0,
    (max, values) => values.length > max ? values.length : max,
  );

  String idFor(int callIndex) => 'call_$callIndex';

  String nameFor(int callIndex) => 'generated_func_$callIndex';

  String argumentPart(int callIndex, int partIndex) {
    final value = argumentPartValuesByCall[callIndex][partIndex];
    return 'c${callIndex}_p${partIndex}_v$value;';
  }

  String expectedArgumentsFor(int callIndex) {
    return [
      for (
        var partIndex = 0;
        partIndex < argumentPartValuesByCall[callIndex].length;
        partIndex++
      )
        argumentPart(callIndex, partIndex),
    ].join();
  }

  @override
  String toString() {
    return '_GeneratedToolCallStream('
        'argumentPartValuesByCall: $argumentPartValuesByCall)';
  }
}

class _GeneratedCompleteToolCallBatch {
  const _GeneratedCompleteToolCallBatch({
    required this.values,
  });

  final List<int> values;

  int get callCount => values.length;

  String idFor(int callIndex) => 'complete_call_$callIndex';

  String nameFor(int callIndex) => 'complete_func_$callIndex';

  String argumentsFor(int callIndex) => '{"value":${values[callIndex]}}';

  AiStreamDelta get delta {
    return AiStreamDelta(
      toolCalls: [
        for (var callIndex = 0; callIndex < values.length; callIndex++)
          AiToolCallChunk(
            index: 0,
            id: idFor(callIndex),
            name: nameFor(callIndex),
            arguments: argumentsFor(callIndex),
          ),
      ],
    );
  }

  @override
  String toString() => '_GeneratedCompleteToolCallBatch(values: $values)';
}

extension _AnyToolCallAccumulatorScenarios on Any {
  Generator<List<int>> get toolCallArgumentPartValues =>
      listWithLengthInRange(1, 6, intInRange(0, 10000));

  Generator<_GeneratedCompleteToolCallBatch> get completeToolCallBatch =>
      combine2(
        listWithLengthInRange(2, 5, intInRange(0, 10000)),
        choose([false, true]),
        (
          List<int> values,
          bool reverseCallOrder,
        ) => _GeneratedCompleteToolCallBatch(
          values: reverseCallOrder ? values.reversed.toList() : values,
        ),
      );

  Generator<_GeneratedToolCallStream> get toolCallStream => combine2(
    listWithLengthInRange(1, 5, toolCallArgumentPartValues),
    choose([false, true]),
    (
      List<List<int>> argumentPartValuesByCall,
      bool reverseCallOrder,
    ) => _GeneratedToolCallStream(
      argumentPartValuesByCall: reverseCallOrder
          ? argumentPartValuesByCall.reversed.toList()
          : argumentPartValuesByCall,
    ),
  );
}

/// Test bench around a fresh [ToolCallAccumulator]. Encapsulates the two
/// flows the property tests below use — feeding a multi-part indexed stream
/// and asserting that the accumulated tool calls match the scenario's
/// expected name → arguments mapping with a configurable id matcher.
class _AccumulatorBench {
  _AccumulatorBench() : _accumulator = ToolCallAccumulator();

  final ToolCallAccumulator _accumulator;

  /// Feeds [scenario] into the accumulator as a parallel indexed stream:
  /// one opening chunk per call (with optional empty id), then continuation
  /// chunks that re-emit only the arguments at each subsequent part.
  void runStream(
    _GeneratedToolCallStream scenario, {
    required bool startWithEmptyIds,
    required bool continueWithEmptyIds,
  }) {
    for (var callIndex = 0; callIndex < scenario.callCount; callIndex++) {
      _accumulator.processChunk(
        AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: callIndex,
              id: startWithEmptyIds ? '' : scenario.idFor(callIndex),
              name: scenario.nameFor(callIndex),
              arguments: scenario.argumentPart(callIndex, 0),
            ),
          ],
        ),
      );
    }

    for (var partIndex = 1; partIndex < scenario.maxPartCount; partIndex++) {
      for (var callIndex = 0; callIndex < scenario.callCount; callIndex++) {
        if (partIndex >= scenario.argumentPartValuesByCall[callIndex].length) {
          continue;
        }

        _accumulator.processChunk(
          AiStreamDelta(
            toolCalls: [
              AiToolCallChunk(
                index: callIndex,
                id: continueWithEmptyIds ? '' : null,
                arguments: scenario.argumentPart(callIndex, partIndex),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Asserts the post-run accumulator contains exactly one tool call per
  /// `scenario.callCount`, that each call's arguments match the per-index
  /// accumulation, and that ids satisfy [idMatcher]. Stream order is not
  /// asserted because the property tests look the tool call up by name.
  void expectStreamMatches(
    _GeneratedToolCallStream scenario, {
    required Matcher Function(int callIndex) idMatcher,
    required String reasonForArguments,
  }) {
    final toolCalls = _accumulator.toToolCalls();
    expect(toolCalls, hasLength(scenario.callCount));

    for (var callIndex = 0; callIndex < scenario.callCount; callIndex++) {
      final toolCall = toolCalls.singleWhere(
        (call) => call.name == scenario.nameFor(callIndex),
      );
      expect(toolCall.id, idMatcher(callIndex));
      expect(
        toolCall.arguments,
        scenario.expectedArgumentsFor(callIndex),
        reason: '$reasonForArguments for $scenario',
      );
    }
  }

  int get count => _accumulator.count;
}

void main() {
  group('ToolCallAccumulator', () {
    late ToolCallAccumulator accumulator;

    setUp(() {
      accumulator = ToolCallAccumulator();
    });

    group('processChunk', () {
      test('handles null delta', () {
        accumulator.processChunk(null);
        expect(accumulator.hasToolCalls, isFalse);
        expect(accumulator.count, 0);
      });

      test('handles delta without tool calls', () {
        const delta = AiStreamDelta(
          content: 'Hello',
        );
        accumulator.processChunk(delta);
        expect(accumulator.hasToolCalls, isFalse);
      });

      test('accumulates single complete tool call', () {
        const delta = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_123',
              name: 'test_function',
              arguments: '{"key": "value"}',
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.hasToolCalls, isTrue);
        expect(accumulator.count, 1);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 1);
        expect(toolCalls.first.name, 'test_function');
        expect(toolCalls.first.arguments, '{"key": "value"}');
      });

      test('accumulates multiple complete tool calls in single chunk', () {
        const delta = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              name: 'function_one',
              arguments: '{"a": 1}',
            ),
            AiToolCallChunk(
              index: 0,
              name: 'function_two',
              arguments: '{"b": 2}',
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.count, 2);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 2);
        expect(toolCalls[0].name, 'function_one');
        expect(toolCalls[1].name, 'function_two');
      });

      test('accumulates streamed tool call chunks by ID', () {
        // First chunk - starts the tool call
        const chunk1 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_abc',
              name: 'my_function',
              arguments: '{"par',
            ),
          ],
        );

        // Second chunk - continues arguments (no ID, uses index)
        const chunk2 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              arguments: 'am": "val',
            ),
          ],
        );

        // Third chunk - finishes arguments
        const chunk3 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              arguments: 'ue"}',
            ),
          ],
        );

        accumulator
          ..processChunk(chunk1)
          ..processChunk(chunk2)
          ..processChunk(chunk3);

        expect(accumulator.count, 1);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 1);
        expect(toolCalls.first.name, 'my_function');
        expect(toolCalls.first.arguments, '{"param": "value"}');
      });

      test('accumulates multiple parallel tool calls', () {
        // First tool call starts
        const chunk1 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_1',
              name: 'func_a',
              arguments: '{"x": ',
            ),
          ],
        );

        // Second tool call starts
        const chunk2 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 1,
              id: 'call_2',
              name: 'func_b',
              arguments: '{"y": ',
            ),
          ],
        );

        // First tool call continues
        const chunk3 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              arguments: '1}',
            ),
          ],
        );

        // Second tool call continues
        const chunk4 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 1,
              arguments: '2}',
            ),
          ],
        );

        accumulator
          ..processChunk(chunk1)
          ..processChunk(chunk2)
          ..processChunk(chunk3)
          ..processChunk(chunk4);

        expect(accumulator.count, 2);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 2);

        final funcA = toolCalls.firstWhere(
          (tc) => tc.name == 'func_a',
        );
        final funcB = toolCalls.firstWhere(
          (tc) => tc.name == 'func_b',
        );

        expect(funcA.arguments, '{"x": 1}');
        expect(funcB.arguments, '{"y": 2}');
      });

      test('continues last tool call when chunk has no ID or index', () {
        // Start a tool call
        const chunk1 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_1',
              name: 'my_func',
              arguments: '{"start": ',
            ),
          ],
        );

        // Continue without ID or index (should append to last)
        const chunk2 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              arguments: '"middle", ',
            ),
          ],
        );

        // Another continuation without ID or index
        const chunk3 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              arguments: '"end": true}',
            ),
          ],
        );

        accumulator
          ..processChunk(chunk1)
          ..processChunk(chunk2)
          ..processChunk(chunk3);

        expect(accumulator.count, 1);
        final toolCalls = accumulator.toToolCalls();
        expect(
          toolCalls.first.arguments,
          '{"start": "middle", "end": true}',
        );
      });

      test('handles chunk with empty ID string', () {
        const delta = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: '', // Empty string ID
              name: 'empty_id_func',
              arguments: '{"test": true}',
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.count, 1);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.first.id, startsWith('tool_'));
        expect(toolCalls.first.name, 'empty_id_func');
      });

      test('handles continuation chunk without function data', () {
        // Start a tool call
        const chunk1 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_1',
              name: 'my_func',
              arguments: '{"key": "value"}',
            ),
          ],
        );

        // Continuation chunk without function (edge case)
        const chunk2 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
            ),
          ],
        );

        accumulator
          ..processChunk(chunk1)
          ..processChunk(chunk2);

        // Should still have the original tool call unchanged
        expect(accumulator.count, 1);
        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.first.arguments, '{"key": "value"}');
      });

      test('ignores continuation when no tool calls exist', () {
        // Try to continue without any existing tool calls
        const chunk = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              arguments: 'orphan data',
            ),
          ],
        );

        accumulator.processChunk(chunk);

        // Should not create any tool calls
        expect(accumulator.hasToolCalls, isFalse);
        expect(accumulator.count, 0);
      });

      test('appends continuation chunks that repeat the explicit ID', () {
        const chunk1 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_repeat',
              name: 'repeat_func',
              arguments: '{"a": ',
            ),
          ],
        );

        // Some providers repeat the same non-empty id on continuation chunks
        // and only ship more arguments. The accumulator must append rather
        // than reset the entry.
        const chunk2 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_repeat',
              arguments: '1, "b": ',
            ),
          ],
        );

        const chunk3 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_repeat',
              arguments: '2}',
            ),
          ],
        );

        accumulator
          ..processChunk(chunk1)
          ..processChunk(chunk2)
          ..processChunk(chunk3);

        expect(accumulator.count, 1);
        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls, hasLength(1));
        expect(toolCalls.first.id, 'call_repeat');
        expect(toolCalls.first.name, 'repeat_func');
        expect(toolCalls.first.arguments, '{"a": 1, "b": 2}');
      });

      test('preserves function name when continuing with only arguments', () {
        // Start a tool call with name and partial arguments
        const chunk1 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_1',
              name: 'my_function',
              arguments: '{"a": ',
            ),
          ],
        );

        // Continue with only arguments (no name)
        const chunk2 = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              arguments: '1}',
            ),
          ],
        );

        accumulator
          ..processChunk(chunk1)
          ..processChunk(chunk2);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 1);
        expect(toolCalls.first.name, 'my_function');
        expect(toolCalls.first.arguments, '{"a": 1}');
      });

      Glados(any.toolCallStream).test(
        'accumulates generated parallel indexed tool-call streams',
        (scenario) {
          final bench = _AccumulatorBench()
            ..runStream(
              scenario,
              startWithEmptyIds: false,
              continueWithEmptyIds: false,
            );

          expect(bench.count, scenario.callCount);
          bench.expectStreamMatches(
            scenario,
            idMatcher: (callIndex) => equals(scenario.idFor(callIndex)),
            reasonForArguments: 'Arguments should be appended by index',
          );
        },
        tags: 'glados',
      );

      Glados(any.toolCallStream).test(
        'treats empty continuation IDs as missing IDs',
        (scenario) {
          _AccumulatorBench()
            ..runStream(
              scenario,
              startWithEmptyIds: true,
              continueWithEmptyIds: true,
            )
            ..expectStreamMatches(
              scenario,
              idMatcher: (_) => startsWith('tool_'),
              reasonForArguments: 'Empty continuation IDs should not split',
            );
        },
        tags: 'glados',
      );

      Glados(any.completeToolCallBatch).test(
        'preserves explicit IDs for generated complete tool-call batches',
        (scenario) {
          final generatedAccumulator = ToolCallAccumulator()
            ..processChunk(scenario.delta);

          expect(generatedAccumulator.count, scenario.callCount);
          final toolCalls = generatedAccumulator.toToolCalls();
          expect(toolCalls, hasLength(scenario.callCount));

          for (var callIndex = 0; callIndex < scenario.callCount; callIndex++) {
            expect(toolCalls[callIndex].id, scenario.idFor(callIndex));
            expect(
              toolCalls[callIndex].name,
              scenario.nameFor(callIndex),
            );
            expect(
              toolCalls[callIndex].arguments,
              scenario.argumentsFor(callIndex),
            );
          }
        },
        tags: 'glados',
      );
    });

    group('toToolCalls', () {
      test('returns empty list when no tool calls accumulated', () {
        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls, isEmpty);
      });

      test('skips tool calls with empty arguments', () {
        const delta = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_empty',
              name: 'empty_func',
              arguments: '',
            ),
            AiToolCallChunk(
              index: 1,
              id: 'call_valid',
              name: 'valid_func',
              arguments: '{"valid": true}',
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.count, 2); // Both are accumulated

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 1); // But only valid one is returned
        expect(toolCalls.first.name, 'valid_func');
      });

      test('generates unique IDs for tool calls without IDs', () {
        const delta = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              name: 'func_1',
              arguments: '{"a": 1}',
            ),
            AiToolCallChunk(
              index: 0,
              name: 'func_2',
              arguments: '{"b": 2}',
            ),
          ],
        );

        accumulator.processChunk(delta);
        final toolCalls = accumulator.toToolCalls();

        expect(toolCalls.length, 2);
        expect(toolCalls[0].id, isNot(equals(toolCalls[1].id)));
        expect(toolCalls[0].id, startsWith('tool_'));
        expect(toolCalls[1].id, startsWith('tool_'));
      });
    });

    group('hasToolCalls', () {
      test('returns false initially', () {
        expect(accumulator.hasToolCalls, isFalse);
      });

      test('returns true after processing tool calls', () {
        const delta = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_1',
              name: 'func',
              arguments: '{}',
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.hasToolCalls, isTrue);
      });
    });

    group('count', () {
      test('returns 0 initially', () {
        expect(accumulator.count, 0);
      });

      test('returns correct count after processing', () {
        const delta = AiStreamDelta(
          toolCalls: [
            AiToolCallChunk(
              index: 0,
              id: 'call_1',
              name: 'func1',
              arguments: '{}',
            ),
            AiToolCallChunk(
              index: 1,
              id: 'call_2',
              name: 'func2',
              arguments: '{}',
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.count, 2);
      });
    });
  });
}
