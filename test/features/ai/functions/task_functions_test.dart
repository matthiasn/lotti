import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('TaskFunctions.getTools', () {
    test('returns tool definitions for all four task functions', () {
      final tools = TaskFunctions.getTools();
      final names = tools.map((t) => t.function.name).toList();

      expect(names, contains(TaskFunctions.setTaskLanguage));
      expect(names, contains(TaskFunctions.updateTaskEstimate));
      expect(names, contains(TaskFunctions.updateTaskDueDate));
      expect(names, contains(TaskFunctions.updateTaskPriority));
      expect(tools.length, 4);
    });

    test('every tool is of function type', () {
      final tools = TaskFunctions.getTools();
      for (final tool in tools) {
        expect(tool.type, ChatCompletionToolType.function);
      }
    });

    test('set_task_language enum lists all SupportedLanguage codes', () {
      final tools = TaskFunctions.getTools();
      final tool = tools.firstWhere(
        (t) => t.function.name == TaskFunctions.setTaskLanguage,
      );
      final params = tool.function.parameters!;
      final props = params['properties']! as Map<String, dynamic>;
      final lang = props['languageCode']! as Map<String, dynamic>;
      final values = (lang['enum']! as List).cast<String>();

      for (final s in SupportedLanguage.values) {
        expect(values, contains(s.code), reason: 'missing ${s.code}');
      }
      expect(params['required'], ['languageCode', 'confidence', 'reason']);
    });

    test('update_task_estimate clamps to 1..1440 minutes', () {
      final tools = TaskFunctions.getTools();
      final tool = tools.firstWhere(
        (t) => t.function.name == TaskFunctions.updateTaskEstimate,
      );
      final params = tool.function.parameters!;
      final props = params['properties']! as Map<String, dynamic>;
      final minutes = props['minutes']! as Map<String, dynamic>;

      expect(minutes['type'], 'integer');
      expect(minutes['minimum'], 1);
      expect(minutes['maximum'], 1440);
      expect(params['required'], ['minutes', 'reason', 'confidence']);
    });

    test("update_task_due_date description embeds today's date", () {
      final tools = TaskFunctions.getTools();
      final tool = tools.firstWhere(
        (t) => t.function.name == TaskFunctions.updateTaskDueDate,
      );
      final today = DateTime.now().toIso8601String().split('T')[0];
      expect(tool.function.description, contains(today));

      final params = tool.function.parameters!;
      final props = params['properties']! as Map<String, dynamic>;
      final dueDate = props['dueDate']! as Map<String, dynamic>;
      expect(dueDate['format'], 'date');
      expect(params['required'], ['dueDate', 'reason', 'confidence']);
    });

    test('update_task_priority restricts to P0..P3', () {
      final tools = TaskFunctions.getTools();
      final tool = tools.firstWhere(
        (t) => t.function.name == TaskFunctions.updateTaskPriority,
      );
      final params = tool.function.parameters!;
      final props = params['properties']! as Map<String, dynamic>;
      final priority = props['priority']! as Map<String, dynamic>;
      final values = (priority['enum']! as List).cast<String>();

      expect(values, ['P0', 'P1', 'P2', 'P3']);
      expect(params['required'], ['priority']);
    });

    test('confidence enum is consistent across tools that include it', () {
      final tools = TaskFunctions.getTools();
      const expected = ['high', 'medium', 'low'];
      for (final t in tools) {
        final params = t.function.parameters!;
        final props = params['properties']! as Map<String, dynamic>;
        final confidence = props['confidence'] as Map<String, dynamic>?;
        if (confidence == null) continue;
        expect(
          (confidence['enum']! as List).cast<String>(),
          expected,
          reason: 'tool ${t.function.name} confidence enum diverged',
        );
      }
    });
  });

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
  });

  group('TaskFunctionArgs.normalizeToString', () {
    test('passes through actual strings', () {
      expect(TaskFunctionArgs.normalizeToString('hello'), 'hello');
      expect(TaskFunctionArgs.normalizeToString(''), '');
    });

    test('returns null for null input', () {
      expect(TaskFunctionArgs.normalizeToString(null), isNull);
    });

    test('coerces booleans', () {
      expect(TaskFunctionArgs.normalizeToString(true), 'true');
      expect(TaskFunctionArgs.normalizeToString(false), 'false');
    });

    test('coerces numbers', () {
      expect(TaskFunctionArgs.normalizeToString(42), '42');
      expect(TaskFunctionArgs.normalizeToString(3.14), '3.14');
    });

    test('coerces complex objects via toString', () {
      expect(TaskFunctionArgs.normalizeToString([1, 2]), '[1, 2]');
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
