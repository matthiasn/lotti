import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

void main() {
  group('InferenceUsage', () {
    test('creates with all fields', () {
      const usage = InferenceUsage(
        inputTokens: 100,
        outputTokens: 50,
        thoughtsTokens: 25,
        cachedInputTokens: 10,
      );

      expect(usage.inputTokens, 100);
      expect(usage.outputTokens, 50);
      expect(usage.thoughtsTokens, 25);
      expect(usage.cachedInputTokens, 10);
    });

    test('creates with partial fields', () {
      const usage = InferenceUsage(
        inputTokens: 100,
        outputTokens: 50,
      );

      expect(usage.inputTokens, 100);
      expect(usage.outputTokens, 50);
      expect(usage.thoughtsTokens, isNull);
      expect(usage.cachedInputTokens, isNull);
    });

    test('empty constant has no data', () {
      expect(InferenceUsage.empty.inputTokens, isNull);
      expect(InferenceUsage.empty.outputTokens, isNull);
      expect(InferenceUsage.empty.thoughtsTokens, isNull);
      expect(InferenceUsage.empty.cachedInputTokens, isNull);
      expect(InferenceUsage.empty.hasData, isFalse);
    });

    group('totalTokens', () {
      test('sums input and output tokens', () {
        const usage = InferenceUsage(
          inputTokens: 100,
          outputTokens: 50,
        );

        expect(usage.totalTokens, 150);
      });

      test('handles null input tokens', () {
        const usage = InferenceUsage(outputTokens: 50);
        expect(usage.totalTokens, 50);
      });

      test('handles null output tokens', () {
        const usage = InferenceUsage(inputTokens: 100);
        expect(usage.totalTokens, 100);
      });

      test('returns 0 when both are null', () {
        expect(InferenceUsage.empty.totalTokens, 0);
      });
    });

    group('hasData', () {
      test('returns true when inputTokens is set', () {
        const usage = InferenceUsage(inputTokens: 100);
        expect(usage.hasData, isTrue);
      });

      test('returns true when outputTokens is set', () {
        const usage = InferenceUsage(outputTokens: 50);
        expect(usage.hasData, isTrue);
      });

      test('returns true when thoughtsTokens is set', () {
        const usage = InferenceUsage(thoughtsTokens: 25);
        expect(usage.hasData, isTrue);
      });

      test('returns true when cachedInputTokens is set', () {
        const usage = InferenceUsage(cachedInputTokens: 10);
        expect(usage.hasData, isTrue);
      });

      test('returns false when all fields are null', () {
        expect(InferenceUsage.empty.hasData, isFalse);
      });
    });

    group('merge', () {
      test('sums all token counts', () {
        const usage1 = InferenceUsage(
          inputTokens: 100,
          outputTokens: 50,
          thoughtsTokens: 25,
          cachedInputTokens: 10,
        );
        const usage2 = InferenceUsage(
          inputTokens: 200,
          outputTokens: 100,
          thoughtsTokens: 50,
          cachedInputTokens: 20,
        );

        final merged = usage1.merge(usage2);

        expect(merged.inputTokens, 300);
        expect(merged.outputTokens, 150);
        expect(merged.thoughtsTokens, 75);
        expect(merged.cachedInputTokens, 30);
      });

      test('handles null fields in first usage', () {
        const usage1 = InferenceUsage.empty;
        const usage2 = InferenceUsage(
          inputTokens: 100,
          outputTokens: 50,
        );

        final merged = usage1.merge(usage2);

        expect(merged.inputTokens, 100);
        expect(merged.outputTokens, 50);
      });

      test('handles null fields in second usage', () {
        const usage1 = InferenceUsage(
          inputTokens: 100,
          outputTokens: 50,
        );
        const usage2 = InferenceUsage.empty;

        final merged = usage1.merge(usage2);

        expect(merged.inputTokens, 100);
        expect(merged.outputTokens, 50);
      });

      test('returns null when both fields are null', () {
        const usage1 = InferenceUsage(inputTokens: 100);
        const usage2 = InferenceUsage(outputTokens: 50);

        final merged = usage1.merge(usage2);

        expect(merged.inputTokens, 100);
        expect(merged.outputTokens, 50);
        expect(merged.thoughtsTokens, isNull);
        expect(merged.cachedInputTokens, isNull);
      });
    });

    group('toString', () {
      test('includes all non-null fields', () {
        const usage = InferenceUsage(
          inputTokens: 100,
          outputTokens: 50,
          thoughtsTokens: 25,
          cachedInputTokens: 10,
        );

        final str = usage.toString();

        expect(str, contains('input: 100'));
        expect(str, contains('output: 50'));
        expect(str, contains('thoughts: 25'));
        expect(str, contains('cached: 10'));
      });

      test('excludes null fields', () {
        const usage = InferenceUsage(inputTokens: 100);

        final str = usage.toString();

        expect(str, contains('input: 100'));
        expect(str, isNot(contains('output:')));
        expect(str, isNot(contains('thoughts:')));
        expect(str, isNot(contains('cached:')));
      });

      test('handles empty usage', () {
        final str = InferenceUsage.empty.toString();
        expect(str, 'InferenceUsage()');
      });
    });
  });
}
