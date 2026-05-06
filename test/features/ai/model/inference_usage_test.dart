import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/inference_usage.dart';

class _GeneratedInferenceUsageSpec {
  const _GeneratedInferenceUsageSpec({
    required this.inputTokens,
    required this.outputTokens,
    required this.thoughtsTokens,
    required this.cachedInputTokens,
  });

  final int? inputTokens;
  final int? outputTokens;
  final int? thoughtsTokens;
  final int? cachedInputTokens;

  InferenceUsage get usage => InferenceUsage(
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    thoughtsTokens: thoughtsTokens,
    cachedInputTokens: cachedInputTokens,
  );

  bool get hasData =>
      inputTokens != null ||
      outputTokens != null ||
      thoughtsTokens != null ||
      cachedInputTokens != null;

  int get totalTokens => (inputTokens ?? 0) + (outputTokens ?? 0);

  @override
  String toString() {
    return '_GeneratedInferenceUsageSpec('
        'inputTokens: $inputTokens, outputTokens: $outputTokens, '
        'thoughtsTokens: $thoughtsTokens, '
        'cachedInputTokens: $cachedInputTokens)';
  }
}

class _GeneratedInferenceUsageMergeScenario {
  const _GeneratedInferenceUsageMergeScenario({
    required this.left,
    required this.right,
  });

  final _GeneratedInferenceUsageSpec left;
  final _GeneratedInferenceUsageSpec right;

  InferenceUsage get expectedMerged => InferenceUsage(
    inputTokens: _addNullable(left.inputTokens, right.inputTokens),
    outputTokens: _addNullable(left.outputTokens, right.outputTokens),
    thoughtsTokens: _addNullable(left.thoughtsTokens, right.thoughtsTokens),
    cachedInputTokens: _addNullable(
      left.cachedInputTokens,
      right.cachedInputTokens,
    ),
  );

  int? _addNullable(int? a, int? b) {
    if (a == null && b == null) return null;
    return (a ?? 0) + (b ?? 0);
  }

  @override
  String toString() {
    return '_GeneratedInferenceUsageMergeScenario('
        'left: $left, right: $right)';
  }
}

extension _AnyGeneratedInferenceUsage on glados.Any {
  glados.Generator<int?> get optionalTokenCount =>
      glados.AnyUtils(this).choose<int?>([
        null,
        ...List.generate(8, (index) => index * 37),
      ]);

  glados.Generator<_GeneratedInferenceUsageSpec> get inferenceUsageSpec =>
      glados.CombinableAny(this).combine4(
        optionalTokenCount,
        optionalTokenCount,
        optionalTokenCount,
        optionalTokenCount,
        (
          int? inputTokens,
          int? outputTokens,
          int? thoughtsTokens,
          int? cachedInputTokens,
        ) => _GeneratedInferenceUsageSpec(
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          thoughtsTokens: thoughtsTokens,
          cachedInputTokens: cachedInputTokens,
        ),
      );

  glados.Generator<_GeneratedInferenceUsageMergeScenario>
  get inferenceUsageMergeScenario => glados.CombinableAny(this).combine2(
    inferenceUsageSpec,
    inferenceUsageSpec,
    (
      _GeneratedInferenceUsageSpec left,
      _GeneratedInferenceUsageSpec right,
    ) => _GeneratedInferenceUsageMergeScenario(
      left: left,
      right: right,
    ),
  );
}

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

      glados.Glados(
        glados.any.inferenceUsageMergeScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test('matches generated merge and total semantics', (scenario) {
        final left = scenario.left.usage;
        final right = scenario.right.usage;
        final merged = left.merge(right);

        expect(merged, scenario.expectedMerged, reason: '$scenario');
        expect(right.merge(left), scenario.expectedMerged, reason: '$scenario');
        expect(
          left.totalTokens,
          scenario.left.totalTokens,
          reason: '$scenario',
        );
        expect(
          right.totalTokens,
          scenario.right.totalTokens,
          reason: '$scenario',
        );
        expect(left.hasData, scenario.left.hasData, reason: '$scenario');
        expect(right.hasData, scenario.right.hasData, reason: '$scenario');
        expect(InferenceUsage.fromJson(merged.toJson()), merged);
      });
    });

    group('toJson / fromJson', () {
      test('round-trips with all fields', () {
        const usage = InferenceUsage(
          inputTokens: 100,
          outputTokens: 50,
          thoughtsTokens: 25,
          cachedInputTokens: 10,
        );

        final json = usage.toJson();
        final restored = InferenceUsage.fromJson(json);

        expect(restored, usage);
        expect(json['inputTokens'], 100);
        expect(json['outputTokens'], 50);
        expect(json['thoughtsTokens'], 25);
        expect(json['cachedInputTokens'], 10);
      });

      test('round-trips with partial fields', () {
        const usage = InferenceUsage(inputTokens: 42);

        final json = usage.toJson();
        final restored = InferenceUsage.fromJson(json);

        expect(restored, usage);
        expect(json.containsKey('outputTokens'), isFalse);
      });

      test('round-trips empty usage', () {
        final json = InferenceUsage.empty.toJson();
        final restored = InferenceUsage.fromJson(json);

        expect(restored, InferenceUsage.empty);
        expect(json, isEmpty);
      });

      test('fromJson handles missing keys as null', () {
        final usage = InferenceUsage.fromJson(const <String, dynamic>{});
        expect(usage.inputTokens, isNull);
        expect(usage.outputTokens, isNull);
        expect(usage.hasData, isFalse);
      });
    });

    group('equality', () {
      test('equal when all fields match', () {
        const a = InferenceUsage(inputTokens: 10, outputTokens: 20);
        const b = InferenceUsage(inputTokens: 10, outputTokens: 20);

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('not equal when fields differ', () {
        const a = InferenceUsage(inputTokens: 10, outputTokens: 20);
        const b = InferenceUsage(inputTokens: 10, outputTokens: 30);

        expect(a, isNot(b));
      });

      test('empty usages are equal', () {
        expect(InferenceUsage.empty, InferenceUsage.empty);
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
