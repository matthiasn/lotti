import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/agent_tool_arg_parsing.dart';

/// Concrete host for the [ObservationRecordParsing] mixin under test.
class _Parser with ObservationRecordParsing {}

void main() {
  group('parseAgentToolArguments', () {
    test('parses a plain JSON object', () {
      expect(
        parseAgentToolArguments('{"title": "hello", "n": 3}'),
        {'title': 'hello', 'n': 3},
      );
    });

    test('treats empty and "{}" payloads as an empty map', () {
      expect(parseAgentToolArguments(''), isEmpty);
      expect(parseAgentToolArguments('   '), isEmpty);
      expect(parseAgentToolArguments('{}'), isEmpty);
    });

    test('parses markdown-fenced JSON, with and without a language tag', () {
      expect(
        parseAgentToolArguments('```json\n{"a": 1}\n```'),
        {'a': 1},
      );
      expect(
        parseAgentToolArguments('```\n{"b": 2}\n```'),
        {'b': 2},
      );
    });

    test('throws the sanitized exception for malformed plain JSON', () {
      const raw = '{not valid json with secret token abc123';
      expect(
        () => parseAgentToolArguments(raw),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Cannot parse tool arguments',
          ),
        ),
      );
    });

    test(
      'throws the sanitized exception for malformed fenced JSON '
      'without leaking the raw content',
      () {
        const secret = 'super-secret-user-content-9001';
        const raw = '```json\n{broken $secret\n```';
        try {
          parseAgentToolArguments(raw);
          fail('expected a FormatException');
        } on FormatException catch (e) {
          // The sanitized message is used and the raw fenced content — which can
          // carry user-authored text routed to logs — is never embedded.
          expect(e.message, 'Cannot parse tool arguments');
          expect(e.toString(), isNot(contains(secret)));
        }
      },
    );

    test('throws when the decoded JSON is not an object', () {
      // A bare JSON array decodes fine but is not a Map → sanitized throw.
      expect(
        () => parseAgentToolArguments('[1, 2, 3]'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Cannot parse tool arguments',
          ),
        ),
      );
    });
  });

  group('ObservationRecordParsing', () {
    final parser = _Parser();

    test('parseObservationPriority matches known values leniently', () {
      expect(
        parser.parseObservationPriority('notable'),
        ObservationPriority.notable,
      );
      expect(
        parser.parseObservationPriority('  CRITICAL '),
        ObservationPriority.critical,
      );
    });

    test('parseObservationPriority falls back to routine', () {
      expect(
        parser.parseObservationPriority(null),
        ObservationPriority.routine,
      );
      expect(
        parser.parseObservationPriority('whatever'),
        ObservationPriority.routine,
      );
    });

    test('parseObservationCategory matches known values leniently', () {
      expect(
        parser.parseObservationCategory('excellence'),
        ObservationCategory.excellence,
      );
      // Underscore- and case-insensitive: 'template_improvement' resolves.
      expect(
        parser.parseObservationCategory('Template_Improvement'),
        ObservationCategory.templateImprovement,
      );
    });

    test('parseObservationCategory falls back to operational', () {
      expect(
        parser.parseObservationCategory(null),
        ObservationCategory.operational,
      );
      expect(
        parser.parseObservationCategory('nonsense'),
        ObservationCategory.operational,
      );
    });
  });
}
