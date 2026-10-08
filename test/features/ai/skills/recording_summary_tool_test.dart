import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/skills/entry_summary_tool.dart';
import 'package:lotti/features/ai/skills/recording_summary_tool.dart';
import 'package:lotti/features/ai/skills/transcript_name_correction_tool.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:openai_dart/openai_dart.dart';

ChatCompletionMessageToolCall _call(
  Object arguments, {
  String name = recordingSummaryToolName,
}) => ChatCompletionMessageToolCall(
  id: 'call-1',
  type: ChatCompletionMessageToolCallType.function,
  function: ChatCompletionMessageFunctionCall(
    name: name,
    arguments: arguments is String ? arguments : jsonEncode(arguments),
  ),
);

const Map<String, String> _tiers = {
  EntrySummaryToolArgs.oneLiner: 'Build moved.',
  EntrySummaryToolArgs.tldr: 'Rollout on Monday.',
  EntrySummaryToolArgs.summary: '## Rollout',
};

SpeechDictionaryEntry _entry(String term, {List<String>? misheardAs}) =>
    SpeechDictionaryEntry(
      id: 'entry-$term',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      term: term,
      vectorClock: null,
      misheardAs: misheardAs,
    );

void main() {
  group('recordingSummaryTool', () {
    test('asks for the three tiers and the corrections, nothing else', () {
      final parameters = recordingSummaryTool.function.parameters!;

      expect(parameters['required'], [
        ...EntrySummaryToolArgs.required,
        TranscriptNameCorrectionToolArgs.corrections,
      ]);
      expect(parameters['additionalProperties'], isFalse);
      expect(
        (parameters['properties']! as Map).keys,
        unorderedEquals([
          ...EntrySummaryToolArgs.required,
          TranscriptNameCorrectionToolArgs.corrections,
        ]),
      );
    });
  });

  group('parseRecordingSummaryToolCall', () {
    test('decodes the tiers and the corrections', () {
      final result = parseRecordingSummaryToolCall([
        _call({
          ..._tiers,
          TranscriptNameCorrectionToolArgs.corrections: [
            {
              TranscriptNameCorrectionToolArgs.heard: 'Cuban Eddies',
              TranscriptNameCorrectionToolArgs.term: 'Kubernetes',
              TranscriptNameCorrectionToolArgs.context: 'to Cuban Eddies',
            },
          ],
        }),
      ]);

      expect(result.summary.oneLiner, 'Build moved.');
      expect(result.corrections, [
        (heard: 'Cuban Eddies', term: 'Kubernetes', context: 'to Cuban Eddies'),
      ]);
    });

    test('a missing correction list is no correction, not a failure', () {
      final result = parseRecordingSummaryToolCall([_call(_tiers)]);

      expect(result.summary.tldr, 'Rollout on Monday.');
      expect(result.corrections, isEmpty);
    });

    test('rejects a call to another tool, and missing tiers', () {
      expect(
        () => parseRecordingSummaryToolCall([
          _call(_tiers, name: entrySummaryToolName),
        ]),
        throwsA(isA<EntrySummaryToolException>()),
      );
      expect(
        () => parseRecordingSummaryToolCall([
          _call({EntrySummaryToolArgs.oneLiner: 'Only this.'}),
        ]),
        throwsA(isA<EntrySummaryToolException>()),
      );
    });
  });

  group('recordingCorrectionPrompt', () {
    test('lists each term with the spellings it was misheard as', () {
      final prompt = recordingCorrectionPrompt([
        _entry('Kubernetes', misheardAs: ['Cuban Eddies', 'Cooper Netties']),
        _entry('Lotti'),
      ]);

      expect(prompt, startsWith('**Speech Dictionary:**'));
      expect(
        prompt,
        contains(
          '- Kubernetes (misheard before as: Cuban Eddies, Cooper Netties)\n'
          '- Lotti\n',
        ),
      );
      // A listed spelling can be the word that was meant.
      expect(prompt, contains('can also be a real word'));
    });

    test('is empty when no term reaches the recording', () {
      expect(recordingCorrectionPrompt(const []), isEmpty);
    });
  });

  group('applyRecordingCorrections', () {
    const transcript = 'we moved the build to cuban eddies today';

    test('accepts a lower-case mishearing the term is known for', () {
      final result = applyRecordingCorrections(
        transcript,
        [(heard: 'cuban eddies', term: 'Kubernetes', context: null)],
        [
          _entry('Kubernetes', misheardAs: ['Cuban Eddies']),
        ],
      );

      expect(result.text, 'we moved the build to Kubernetes today');
      expect(result.applied, [(from: 'cuban eddies', to: 'Kubernetes')]);
    });

    test('refuses a lower-case word it has no evidence for', () {
      final result = applyRecordingCorrections(
        transcript,
        [(heard: 'cuban eddies', term: 'Kubernetes', context: null)],
        [_entry('Kubernetes')],
      );

      expect(result.text, transcript);
      expect(result.applied, isEmpty);
    });

    test('refuses a replacement that is not a dictionary term', () {
      final result = applyRecordingCorrections(
        'Deploy to Cuban Eddies.',
        [(heard: 'Cuban Eddies', term: 'Kubernetes Engine', context: null)],
        [_entry('Kubernetes')],
      );

      expect(result.applied, isEmpty);
    });

    test('changes nothing without corrections or entries', () {
      expect(
        applyRecordingCorrections(transcript, const [], [
          _entry('Kubernetes'),
        ]).text,
        transcript,
      );
      expect(
        applyRecordingCorrections(transcript, [
          (heard: 'Cuban', term: 'Kubernetes', context: null),
        ], const []).applied,
        isEmpty,
      );
    });
  });

  test('knownMisheardForms indexes lower-cased spellings by term', () {
    expect(
      knownMisheardForms([
        _entry('Kubernetes', misheardAs: ['Cuban Eddies']),
        _entry('Lotti'),
      ]),
      {
        'Kubernetes': {'cuban eddies'},
      },
    );
  });

  group('withKnownTerms', () {
    SpeechDictionaryEntry entry(String term, {List<String>? misheardAs}) =>
        SpeechDictionaryEntry(
          id: 'entry-$term',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          term: term,
          vectorClock: null,
          categoryIds: const ['cat'],
          misheardAs: misheardAs,
        );

    test(
      'adds each expected name once as an uncategorized entry, and keeps a '
      'dictionary entry the name already has',
      () {
        final kubernetes = entry('Kubernetes', misheardAs: ['Cuban Eddies']);

        final merged = withKnownTerms(
          [kubernetes],
          const [
            'kubernetes',
            ' Commander Pip Frostbeak ',
            'Wanja',
            'Wanja',
            '',
          ],
        );

        expect(merged.first, same(kubernetes));
        expect(merged.map((e) => e.term), [
          'Kubernetes',
          'Commander Pip Frostbeak',
          'Wanja',
        ]);
        final name = merged[1];
        expect(name.categoryIds, isNull);
        expect(name.misheardAs, isNull);
        expect(name.id, speechDictionaryEntryId('Commander Pip Frostbeak'));
      },
    );

    test('a correction to an expected name is applied like a term', () {
      final entries = withKnownTerms(const [], const ['Wanja']);

      final result = applyRecordingCorrections(
        'Then Vanja called.',
        const [(heard: 'Vanja', term: 'Wanja', context: 'Then Vanja called')],
        entries,
      );

      expect(result.text, 'Then Wanja called.');
      expect(result.applied, [(from: 'Vanja', to: 'Wanja')]);
    });
  });
}
