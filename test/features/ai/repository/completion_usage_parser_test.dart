import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/repository/completion_usage_parser.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('parseCompletionUsage', () {
    test('parses token usage without casting map keys', () {
      final ignoredKey = Object();

      final usage = parseCompletionUsage({
        ignoredKey: 'ignored',
        'prompt_tokens': 12,
        'completion_tokens': '8',
        'prompt_tokens_details': {
          ignoredKey: 'ignored',
          'cached_tokens': '3',
        },
        'completion_tokens_details': {
          ignoredKey: 'ignored',
          'reasoning_tokens': 5,
        },
      });

      expect(usage, isNotNull);
      expect(usage!.promptTokens, 12);
      expect(usage.completionTokens, 8);
      expect(usage.totalTokens, 20);
      expect(usage.promptTokensDetails?.cachedTokens, 3);
      expect(usage.completionTokensDetails?.reasoningTokens, 5);
    });

    test('uses camelCase and input/output token aliases', () {
      final usage = parseCompletionUsage({
        'input_tokens': 4,
        'output_tokens': 6,
        'promptTokensDetails': {'cachedTokens': 2},
        'outputTokensDetails': {'reasoningTokens': 1},
      });

      expect(usage, isNotNull);
      expect(usage!.promptTokens, 4);
      expect(usage.completionTokens, 6);
      expect(usage.totalTokens, 10);
      expect(usage.promptTokensDetails?.cachedTokens, 2);
      expect(usage.completionTokensDetails?.reasoningTokens, 1);
    });

    test(
      'defaults prompt tokens when only completion-side data is reported',
      () {
        final usage = parseCompletionUsage({
          'completion_tokens': 6,
        });

        expect(usage, isNotNull);
        expect(usage!.promptTokens, 0);
        expect(usage.completionTokens, 6);
        expect(usage.totalTokens, 6);
      },
    );

    test(
      'defaults completion tokens when only prompt-side data is reported',
      () {
        final usage = parseCompletionUsage({
          'prompt_tokens': 9,
        });

        expect(usage, isNotNull);
        expect(usage!.promptTokens, 9);
        expect(usage.completionTokens, 0);
        expect(usage.totalTokens, 9);
      },
    );

    test('ignores non-token usage payloads', () {
      expect(parseCompletionUsage({'duration': 1.25}), isNull);
      expect(parseCompletionUsage('not a map'), isNull);
    });
  });

  group('usage properties', () {
    // A payload is JSON, and Dart's JSON decoder turns an out-of-range
    // number such as 1e400 into infinity. A malformed count is no count; it
    // must not take the whole response down with it.
    test('a non-finite token count is ignored rather than thrown on', () {
      final usage = parseCompletionUsage(
        jsonDecode('{"prompt_tokens": 1e400, "completion_tokens": 4}'),
      );

      expect(usage?.promptTokens, 0);
      expect(usage?.completionTokens, 4);
      expect(
        parseCompletionUsage({'total_tokens': double.nan}),
        isNull,
      );
    });

    glados.Glados(
      glados.any.usagePayload,
      glados.ExploreConfig(numRuns: 500),
    ).test(
      'any payload parses without throwing, and only when it holds a count',
      (payload) {
        // The first present spelling of a field is the one that is read.
        int? read(List<String> keys, [Map<dynamic, dynamic>? from]) {
          final source = from ?? payload;
          for (final key in keys) {
            final value = source[key];
            if (value == null) continue;
            return switch (value) {
              int() => value,
              double() when value.isFinite => value.toInt(),
              String() => int.tryParse(value),
              _ => null,
            };
          }
          return null;
        }

        final prompt = read(['prompt_tokens', 'input_tokens', 'promptTokens']);
        final completion = read([
          'completion_tokens',
          'output_tokens',
          'completionTokens',
        ]);
        final total = read(['total_tokens', 'totalTokens']);
        final cached =
            read(['cached_tokens', 'cachedTokens']) ??
            read(
              ['cached_tokens'],
              {
                ...?_asMap(payload['prompt_tokens_details']),
              },
            );

        final reasoning =
            read(['reasoning_tokens', 'reasoningTokens']) ??
            read(
              ['reasoning_tokens'],
              {
                ...?_asMap(payload['completion_tokens_details']),
              },
            );

        final usage = parseCompletionUsage(payload);

        expect(
          usage == null,
          [prompt, completion, total, cached, reasoning].every(
            (count) => count == null,
          ),
        );
        if (usage == null) return;
        expect(usage.promptTokens, prompt ?? 0);
        expect(usage.completionTokens, completion ?? 0);
        expect(usage.totalTokens, total ?? (prompt ?? 0) + (completion ?? 0));
      },
      tags: 'glados',
    );

    glados.Glados3(
      glados.any.completionUsage,
      glados.any.completionUsage,
      glados.any.completionUsage,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'combining usage is a commutative, associative sum with null as identity',
      (a, b, c) {
        expect(combineCompletionUsage(a, b), combineCompletionUsage(b, a));
        expect(
          combineCompletionUsage(combineCompletionUsage(a, b), c),
          combineCompletionUsage(a, combineCompletionUsage(b, c)),
        );
        expect(combineCompletionUsage(a, null), a);
        expect(combineCompletionUsage(null, a), a);

        int? sum(int? x, int? y) =>
            x == null && y == null ? null : (x ?? 0) + (y ?? 0);
        final both = combineCompletionUsage(a, b);
        if (a == null || b == null) return;
        expect(both!.promptTokens, sum(a.promptTokens, b.promptTokens));
        expect(
          both.completionTokens,
          sum(a.completionTokens, b.completionTokens),
        );
        expect(both.totalTokens, sum(a.totalTokens, b.totalTokens));
        expect(
          both.completionTokensDetails?.reasoningTokens,
          sum(
            a.completionTokensDetails?.reasoningTokens,
            b.completionTokensDetails?.reasoningTokens,
          ),
        );
        expect(
          both.promptTokensDetails?.cachedTokens,
          sum(
            a.promptTokensDetails?.cachedTokens,
            b.promptTokensDetails?.cachedTokens,
          ),
        );
      },
      tags: 'glados',
    );
  });
}

Map<dynamic, dynamic>? _asMap(Object? value) =>
    value is Map<dynamic, dynamic> ? value : null;

const _usageKeys = [
  'prompt_tokens',
  'input_tokens',
  'promptTokens',
  'completion_tokens',
  'output_tokens',
  'completionTokens',
  'total_tokens',
  'totalTokens',
  'cached_tokens',
  'reasoning_tokens',
  'prompt_tokens_details',
  'completion_tokens_details',
  'audio_seconds',
];

final _usageValues = <Object?>[
  null,
  0,
  7,
  -3,
  12.9,
  double.infinity,
  double.nan,
  '42',
  ' 5',
  'many',
  true,
  const [1, 2],
  const {'cached_tokens': 3},
  const {'cached_tokens': 'x'},
  const {'reasoning_tokens': double.negativeInfinity},
];

extension _AnyUsage on glados.Any {
  glados.Generator<Map<dynamic, dynamic>> get usagePayload =>
      glados.ListAnys(this)
          .listWithLengthInRange(
            0,
            6,
            glados.CombinableAny(this).combine2(
              glados.IntAnys(this).intInRange(0, _usageKeys.length),
              glados.IntAnys(this).intInRange(0, _usageValues.length),
              (int key, int value) => MapEntry<dynamic, dynamic>(
                _usageKeys[key],
                _usageValues[value],
              ),
            ),
          )
          .map(Map<dynamic, dynamic>.fromEntries);

  glados.Generator<int?> get _count =>
      glados.IntAnys(this).intInRange(-1, 500).map((n) => n < 0 ? null : n);

  glados.Generator<CompletionUsage?> get completionUsage =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, 5),
        _count,
        _count,
        _count,
        _count,
        _count,
        (
          int shape,
          int? prompt,
          int? completion,
          int? total,
          int? cached,
          int? reasoning,
        ) => shape == 0
            ? null
            : CompletionUsage(
                promptTokens: prompt,
                completionTokens: completion,
                totalTokens: total,
                promptTokensDetails: shape.isOdd
                    ? PromptTokensDetails(cachedTokens: cached)
                    : null,
                completionTokensDetails: shape >= 3
                    ? CompletionTokensDetails(reasoningTokens: reasoning)
                    : null,
              ),
      );
}
