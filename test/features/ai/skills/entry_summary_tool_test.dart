import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/skills/entry_summary_tool.dart';
import 'package:openai_dart/openai_dart.dart';

ChatCompletionMessageToolCall _call(
  String arguments, {
  String name = entrySummaryToolName,
  String id = 'call-1',
}) => ChatCompletionMessageToolCall(
  id: id,
  type: ChatCompletionMessageToolCallType.function,
  function: ChatCompletionMessageFunctionCall(
    name: name,
    arguments: arguments,
  ),
);

String _args({
  String? oneLiner = 'Agreed to ship the export flow behind a flag.',
  String? tldr = 'The team chose a flagged rollout over a big-bang release.',
  String? summary = '## Decisions\n- Ship behind a flag',
}) => jsonEncode({
  EntrySummaryToolArgs.oneLiner: ?oneLiner,
  EntrySummaryToolArgs.tldr: ?tldr,
  EntrySummaryToolArgs.summary: ?summary,
});

void main() {
  group('parseEntrySummaryToolCall', () {
    test('returns all three tiers from a well-formed call', () {
      final summary = parseEntrySummaryToolCall([_call(_args())]);

      expect(summary.oneLiner, 'Agreed to ship the export flow behind a flag.');
      expect(
        summary.tldr,
        'The team chose a flagged rollout over a big-bang release.',
      );
      expect(summary.summary, '## Decisions\n- Ship behind a flag');
    });

    test('trims surrounding whitespace on every tier', () {
      final summary = parseEntrySummaryToolCall([
        _call(
          _args(
            oneLiner: '  Padded one-liner.  ',
            tldr: '\n Padded tldr. \n',
            summary: '\n\n## Body\n',
          ),
        ),
      ]);

      expect(summary.oneLiner, 'Padded one-liner.');
      expect(summary.tldr, 'Padded tldr.');
      expect(summary.summary, '## Body');
    });

    test('picks the summary call out of a mixed tool-call list', () {
      final summary = parseEntrySummaryToolCall([
        _call('{}', name: 'record_observations', id: 'other'),
        _call(_args()),
      ]);

      expect(summary.oneLiner, 'Agreed to ship the export flow behind a flag.');
    });

    test('ignores a duplicate echoed call and keeps the first', () {
      final summary = parseEntrySummaryToolCall([
        _call(_args(oneLiner: 'First.')),
        _call(_args(oneLiner: 'Second.'), id: 'call-2'),
      ]);

      expect(summary.oneLiner, 'First.');
    });

    test('rejects an empty tool-call list, naming the absence', () {
      expect(
        () => parseEntrySummaryToolCall([]),
        throwsA(
          isA<EntrySummaryToolException>().having(
            (e) => e.reason,
            'reason',
            contains('no tool call'),
          ),
        ),
      );
    });

    test('rejects a call to a different tool, naming what was called', () {
      expect(
        () => parseEntrySummaryToolCall([
          _call(_args(), name: 'update_report'),
        ]),
        throwsA(
          isA<EntrySummaryToolException>().having(
            (e) => e.reason,
            'reason',
            allOf(contains('update_report'), contains(entrySummaryToolName)),
          ),
        ),
      );
    });

    test('rejects arguments that are not valid JSON', () {
      expect(
        () => parseEntrySummaryToolCall([_call('{"oneLiner": ')]),
        throwsA(
          isA<EntrySummaryToolException>().having(
            (e) => e.reason,
            'reason',
            contains('not valid JSON'),
          ),
        ),
      );
    });

    test('rejects arguments that decode to a non-object', () {
      expect(
        () => parseEntrySummaryToolCall([_call('["oneLiner"]')]),
        throwsA(
          isA<EntrySummaryToolException>().having(
            (e) => e.reason,
            'reason',
            contains('not a JSON object'),
          ),
        ),
      );
    });

    for (final field in EntrySummaryToolArgs.required) {
      test('rejects a call missing "$field"', () {
        final decoded = jsonDecode(_args()) as Map<String, dynamic>
          ..remove(field);
        expect(
          () => parseEntrySummaryToolCall([_call(jsonEncode(decoded))]),
          throwsA(
            isA<EntrySummaryToolException>().having(
              (e) => e.reason,
              'reason',
              allOf(contains('missing'), contains(field)),
            ),
          ),
        );
      });

      test('rejects a whitespace-only "$field"', () {
        final decoded = jsonDecode(_args()) as Map<String, dynamic>;
        decoded[field] = '   \n ';
        expect(
          () => parseEntrySummaryToolCall([_call(jsonEncode(decoded))]),
          throwsA(
            isA<EntrySummaryToolException>().having(
              (e) => e.reason,
              'reason',
              allOf(contains('empty'), contains(field)),
            ),
          ),
        );
      });

      test('rejects a non-string "$field"', () {
        final decoded = jsonDecode(_args()) as Map<String, dynamic>;
        decoded[field] = 42;
        expect(
          () => parseEntrySummaryToolCall([_call(jsonEncode(decoded))]),
          throwsA(
            isA<EntrySummaryToolException>().having(
              (e) => e.reason,
              'reason',
              allOf(contains('not a string'), contains(field)),
            ),
          ),
        );
      });
    }

    test('accepts a one-liner exactly at the length limit', () {
      final atLimit = 'x' * entrySummaryOneLinerMaxChars;

      final summary = parseEntrySummaryToolCall([
        _call(_args(oneLiner: atLimit)),
      ]);

      expect(summary.oneLiner.length, entrySummaryOneLinerMaxChars);
    });

    test('rejects a one-liner one character over the limit, reporting '
        'both lengths so the retry prompt can name them', () {
      final overLimit = 'x' * (entrySummaryOneLinerMaxChars + 1);

      expect(
        () => parseEntrySummaryToolCall([_call(_args(oneLiner: overLimit))]),
        throwsA(
          isA<EntrySummaryToolException>().having(
            (e) => e.reason,
            'reason',
            allOf(
              contains('${entrySummaryOneLinerMaxChars + 1} chars'),
              contains('$entrySummaryOneLinerMaxChars limit'),
            ),
          ),
        ),
      );
    });

    test('measures the one-liner limit after trimming, so padding alone '
        'cannot push a valid line over', () {
      final padded = ' ${'x' * entrySummaryOneLinerMaxChars} ';

      final summary = parseEntrySummaryToolCall([
        _call(_args(oneLiner: padded)),
      ]);

      expect(summary.oneLiner.length, entrySummaryOneLinerMaxChars);
    });

    test('does not cap the tldr or the summary — only the one-liner is '
        'rendered on a single line', () {
      final long = 'x' * (entrySummaryOneLinerMaxChars * 10);

      final summary = parseEntrySummaryToolCall([
        _call(_args(tldr: long, summary: long)),
      ]);

      expect(summary.tldr.length, entrySummaryOneLinerMaxChars * 10);
      expect(summary.summary.length, entrySummaryOneLinerMaxChars * 10);
    });
  });

  group('entrySummaryTool schema', () {
    test('requires exactly the three tiers and forbids extra properties', () {
      final parameters = entrySummaryTool.function.parameters!;
      final properties = parameters['properties']! as Map<String, dynamic>;

      expect(
        parameters['required'],
        containsAll(<String>[
          EntrySummaryToolArgs.oneLiner,
          EntrySummaryToolArgs.tldr,
          EntrySummaryToolArgs.summary,
        ]),
      );
      expect(properties.keys, unorderedEquals(EntrySummaryToolArgs.required));
      expect(parameters['additionalProperties'], isFalse);
    });

    test('states the one-liner character budget in the schema the model '
        'reads, so the limit and the prompt cannot drift apart', () {
      final properties =
          entrySummaryTool.function.parameters!['properties']!
              as Map<String, dynamic>;
      final oneLiner =
          properties[EntrySummaryToolArgs.oneLiner]! as Map<String, dynamic>;

      expect(
        oneLiner['description'],
        contains('$entrySummaryOneLinerMaxChars characters'),
      );
    });

    test('pins tool choice to this tool by name', () {
      expect(
        entrySummaryToolChoice.toString(),
        contains(entrySummaryToolName),
      );
    });
  });
}
