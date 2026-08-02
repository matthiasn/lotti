import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/functions/task_functions.dart';

extension _AnyLanguageConfidence on glados.Any {
  glados.Generator<LanguageDetectionConfidence> get languageConfidence =>
      glados.AnyUtils(this).choose(LanguageDetectionConfidence.values);
}

void main() {
  group('SetTaskLanguageResult', () {
    test('round-trips through JSON', () {
      const result = SetTaskLanguageResult(
        languageCode: 'fr',
        confidence: LanguageDetectionConfidence.high,
        reason: 'spoken in French',
      );
      final json = result.toJson();
      expect(json['languageCode'], 'fr');
      expect(json['confidence'], 'high');
      expect(json['reason'], 'spoken in French');

      final back = SetTaskLanguageResult.fromJson(json);
      expect(back, result);
    });

    // Round-trip property over the full field space: catches any drift between
    // the schema literals and the generated (de)serializer for arbitrary
    // language codes, reasons, and every confidence enum value.
    glados.Glados<(String, String, LanguageDetectionConfidence)>(
      glados.CombinableAny(glados.any).combine3(
        glados.any.letterOrDigits,
        glados.any.letterOrDigits,
        glados.any.languageConfidence,
        (String code, String reason, LanguageDetectionConfidence c) =>
            (code, reason, c),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'fromJson(toJson(x)) == x',
      (triple) {
        final original = SetTaskLanguageResult(
          languageCode: triple.$1,
          confidence: triple.$3,
          reason: triple.$2,
        );
        expect(SetTaskLanguageResult.fromJson(original.toJson()), original);
      },
      tags: 'glados',
    );
  });

  group('SetTaskLanguageResult.fromJson — confidence parsing contract', () {
    test('parses every known confidence value', () {
      for (final confidence in LanguageDetectionConfidence.values) {
        final result = SetTaskLanguageResult.fromJson({
          'languageCode': 'en',
          'confidence': confidence.name,
          'reason': 'r',
        });
        expect(result.confidence, confidence);
      }
    });

    test(
      'an unrecognized confidence value throws — LanguageDetectionConfidence '
      'has no unknownEnumValue fallback, so malformed AI output makes the '
      'caller (unified_ai_tool_call_processor) drop the language update via '
      'its catch block instead of degrading to a low-confidence apply',
      () {
        expect(
          () => SetTaskLanguageResult.fromJson({
            'languageCode': 'en',
            'confidence': 'very-high',
            'reason': 'r',
          }),
          throwsA(anything),
        );
      },
    );
  });

  group('TaskFunctionArgs.normalizeToString', () {
    test('returns null for null input', () {
      expect(TaskFunctionArgs.normalizeToString(null), isNull);
    });

    glados.Glados<String>(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'is the identity for any string',
      (s) => expect(TaskFunctionArgs.normalizeToString(s), s),
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.intInRange(-1000000, 1000000),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'coerces any non-string value via toString',
      (n) {
        // Numbers, booleans, and collections all route through toString —
        // exercise a numeric sweep plus the fixed non-string shapes.
        expect(TaskFunctionArgs.normalizeToString(n), n.toString());
        expect(TaskFunctionArgs.normalizeToString(n.isEven), '${n.isEven}');
        expect(
          TaskFunctionArgs.normalizeToString([n, n + 1]),
          '[$n, ${n + 1}]',
        );
      },
      tags: 'glados',
    );

    test('empty string and doubles keep their exact representation', () {
      expect(TaskFunctionArgs.normalizeToString(''), '');
      expect(TaskFunctionArgs.normalizeToString(3.14), '3.14');
    });
  });

  group('TaskFunctionArgs.extractReasonAndConfidence', () {
    test('returns both fields when present as strings', () {
      final out = TaskFunctionArgs.extractReasonAndConfidence(
        <String, dynamic>{'reason': 'because', 'confidence': 'high'},
      );
      expect(out.reason, 'because');
      expect(out.confidence, 'high');
    });

    test('returns nulls when fields are absent', () {
      final out = TaskFunctionArgs.extractReasonAndConfidence(
        <String, dynamic>{},
      );
      expect(out.reason, isNull);
      expect(out.confidence, isNull);
    });

    test('coerces non-string confidence sent by AI', () {
      final out = TaskFunctionArgs.extractReasonAndConfidence(
        <String, dynamic>{'confidence': true, 'reason': 42},
      );
      expect(out.confidence, 'true');
      expect(out.reason, '42');
    });
  });
}
