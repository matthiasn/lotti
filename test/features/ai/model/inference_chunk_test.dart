import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference.dart';

void main() {
  group('LottiUsage', () {
    test('hasTokenData distinguishes no usage from zeroed usage', () {
      // Duration-only audio usage parses to a record with no counts, which
      // callers must treat as "not reported" rather than as zero consumption.
      expect(const LottiUsage().hasTokenData, isFalse);
      expect(const LottiUsage(promptTokens: 0).hasTokenData, isTrue);
      expect(const LottiUsage(reasoningTokens: 3).hasTokenData, isTrue);
      expect(const LottiUsage(cachedInputTokens: 1).hasTokenData, isTrue);
    });

    test('copyWith replaces only the named fields', () {
      const usage = LottiUsage(
        promptTokens: 10,
        completionTokens: 4,
        cachedInputTokens: 6,
      );
      final updated = usage.copyWith(completionTokens: 5);
      expect(updated.completionTokens, 5);
      expect(updated.promptTokens, 10);
      expect(updated.cachedInputTokens, 6);
    });

    test('compares structurally', () {
      expect(
        const LottiUsage(promptTokens: 1, reasoningTokens: 2),
        const LottiUsage(promptTokens: 1, reasoningTokens: 2),
      );
      expect(
        const LottiUsage(promptTokens: 1),
        isNot(const LottiUsage(promptTokens: 2)),
      );
    });
  });

  group('LottiInferenceChunk', () {
    test('textDelta reads the first choice content', () {
      const chunk = LottiInferenceChunk(
        choices: [
          LottiChunkChoice(index: 0, delta: LottiDelta(content: 'hel')),
        ],
      );
      expect(chunk.textDelta, 'hel');
    });

    test('textDelta is null on a usage-only final frame', () {
      // Providers emit a trailing accounting frame with no choices at all.
      const chunk = LottiInferenceChunk(
        choices: [],
        usage: LottiUsage(promptTokens: 1),
      );
      expect(chunk.textDelta, isNull);
      expect(const LottiInferenceChunk().textDelta, isNull);
    });

    test('textDelta is null when the choice carries only tool calls', () {
      const chunk = LottiInferenceChunk(
        choices: [
          LottiChunkChoice(
            index: 0,
            delta: LottiDelta(
              toolCalls: [LottiToolCallChunk(index: 0, name: 'lookup')],
            ),
          ),
        ],
      );
      expect(chunk.textDelta, isNull);
    });

    test('compares choices element-wise', () {
      const a = LottiInferenceChunk(
        id: 'r',
        choices: [
          LottiChunkChoice(index: 0, delta: LottiDelta(content: 'x')),
        ],
      );
      const b = LottiInferenceChunk(
        id: 'r',
        choices: [
          LottiChunkChoice(index: 0, delta: LottiDelta(content: 'x')),
        ],
      );
      const c = LottiInferenceChunk(
        id: 'r',
        choices: [
          LottiChunkChoice(index: 0, delta: LottiDelta(content: 'y')),
        ],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('copyWith replaces only the named fields', () {
      const chunk = LottiInferenceChunk(id: 'r', model: 'm', created: 1);
      final updated = chunk.copyWith(model: 'n');
      expect(updated.model, 'n');
      expect(updated.id, 'r');
      expect(updated.created, 1);
    });
  });

  group('LottiToolCallChunk', () {
    test('treats an absent name and an absent id as distinct fragments', () {
      // Continuation fragments carry neither, and the accumulator relies on
      // being able to tell them apart from opening fragments.
      const opening = LottiToolCallChunk(
        index: 0,
        id: 'c1',
        name: 'lookup',
        arguments: '{',
      );
      const continuation = LottiToolCallChunk(index: 0, arguments: '"q":1}');
      expect(opening, isNot(continuation));
      expect(continuation.id, isNull);
      expect(continuation.name, isNull);
    });
  });
}
