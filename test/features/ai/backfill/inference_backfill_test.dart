import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show ExploreConfig, Glados, any;
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/ai/skill_type.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/backfill/inference_backfill.dart';

import '../../../helpers/entity_factories.dart';
import 'backfill_fixtures.dart';

/// The media states the rule distinguishes, for the generated property.
enum _Media {
  bareImage,
  imageWithText,
  analysedImage,
  bareAudio,
  audioWithOwnText,
  shortTranscript,
  longTranscript,
  summarisedAudio,
  deletedAudio,
  task,
}

JournalEntity _entity(_Media media, int index) {
  final id = 'entry-$index';
  final date = testFixedDate.add(Duration(minutes: index));
  return switch (media) {
    _Media.bareImage || _Media.analysedImage => backfillImage(
      id: id,
      dateFrom: date,
    ),
    _Media.imageWithText => backfillImage(
      id: id,
      text: 'a caption',
      dateFrom: date,
    ),
    _Media.bareAudio => backfillAudio(id: id, dateFrom: date),
    _Media.audioWithOwnText => backfillAudio(
      id: id,
      text: 'my notes',
      dateFrom: date,
    ),
    _Media.shortTranscript => backfillAudio(
      id: id,
      transcript: 'short',
      dateFrom: date,
    ),
    _Media.longTranscript || _Media.summarisedAudio => backfillAudio(
      id: id,
      transcript: longTranscript,
      dateFrom: date,
    ),
    _Media.deletedAudio => backfillAudio(
      id: id,
      dateFrom: date,
      deletedAt: date,
    ),
    _Media.task => TestTaskFactory.create(id: id, dateFrom: date),
  };
}

List<AiResponseEntry> _responses(_Media media) => switch (media) {
  _Media.analysedImage => [backfillResponse(AiResponseType.imageAnalysis)],
  _Media.summarisedAudio => [backfillResponse(AiResponseType.audioSummary)],
  _ => const [],
};

InferenceBackfillKind? _expectedKind(_Media media) => switch (media) {
  _Media.bareImage => InferenceBackfillKind.imageAnalysis,
  _Media.bareAudio => InferenceBackfillKind.transcription,
  _Media.longTranscript => InferenceBackfillKind.audioSummary,
  _ => null,
};

extension on glados.Any {
  glados.Generator<List<_Media>> get mediaList =>
      glados.ListAnys(this).listWithLengthInRange(
        0,
        16,
        glados.AnyUtils(this).choose(_Media.values),
      );
}

void main() {
  group('missingInferenceFor', () {
    test('an image with no analysis needs image analysis', () {
      expect(
        missingInferenceFor(backfillImage(), const []),
        InferenceBackfillKind.imageAnalysis,
      );
    });

    test('an image with a linked analysis needs nothing', () {
      expect(
        missingInferenceFor(backfillImage(), [
          backfillResponse(AiResponseType.imageAnalysis),
        ]),
        isNull,
      );
    });

    test('a deleted analysis does not count as one', () {
      expect(
        missingInferenceFor(backfillImage(), [
          backfillResponse(
            AiResponseType.imageAnalysis,
            deletedAt: testFixedDate,
          ),
        ]),
        InferenceBackfillKind.imageAnalysis,
      );
    });

    test('a response of another type does not count as an analysis', () {
      expect(
        missingInferenceFor(backfillImage(), [
          backfillResponse(AiResponseType.promptGeneration),
        ]),
        InferenceBackfillKind.imageAnalysis,
      );
    });

    test('an image carrying its own text counts as analysed', () {
      expect(
        missingInferenceFor(backfillImage(text: 'legacy analysis'), const []),
        isNull,
      );
    });

    test('audio with neither transcript nor text needs transcription', () {
      expect(
        missingInferenceFor(backfillAudio(), const []),
        InferenceBackfillKind.transcription,
      );
    });

    test('audio with whitespace-only text still needs transcription', () {
      expect(
        missingInferenceFor(backfillAudio(text: '   '), const []),
        InferenceBackfillKind.transcription,
      );
    });

    test('audio whose text the user typed is never re-transcribed', () {
      expect(missingInferenceFor(backfillAudio(text: 'notes'), const []), null);
    });

    test('a long transcript without a summary needs a summary', () {
      expect(
        missingInferenceFor(
          backfillAudio(transcript: longTranscript),
          const [],
        ),
        InferenceBackfillKind.audioSummary,
      );
    });

    test('long user text without a transcript needs a summary', () {
      expect(
        missingInferenceFor(backfillAudio(text: longTranscript), const []),
        InferenceBackfillKind.audioSummary,
      );
    });

    test('a transcript too short for the summary run needs nothing', () {
      expect(
        missingInferenceFor(backfillAudio(transcript: 'Buy milk.'), const []),
        isNull,
      );
    });

    test('a summarised recording needs nothing', () {
      expect(
        missingInferenceFor(backfillAudio(transcript: longTranscript), [
          backfillResponse(AiResponseType.audioSummary),
        ]),
        isNull,
      );
    });

    test('a deleted entry needs nothing', () {
      expect(
        missingInferenceFor(
          backfillAudio(deletedAt: testFixedDate),
          const [],
        ),
        isNull,
      );
    });

    test('an entry that is not media needs nothing', () {
      expect(missingInferenceFor(TestTaskFactory.create(), const []), isNull);
    });
  });

  group('findMissingInference', () {
    test('yields one candidate per entry, newest first', () {
      final older = backfillImage(id: 'old', dateFrom: DateTime(2024, 3));
      final newer = backfillAudio(id: 'new', dateFrom: DateTime(2024, 3, 2));
      final done = backfillImage(id: 'done', dateFrom: DateTime(2024, 3, 3));

      final candidates = findMissingInference(
        [older, newer, done],
        {
          'done': [backfillResponse(AiResponseType.imageAnalysis)],
        },
      );

      expect(candidates, [
        InferenceBackfillCandidate(
          entryId: 'new',
          kind: InferenceBackfillKind.transcription,
          capturedAt: DateTime(2024, 3, 2),
        ),
        InferenceBackfillCandidate(
          entryId: 'old',
          kind: InferenceBackfillKind.imageAnalysis,
          capturedAt: DateTime(2024, 3),
        ),
      ]);
    });

    test('a task with no media yields nothing', () {
      expect(findMissingInference(const [], const {}), isEmpty);
    });

    Glados(any.mediaList, ExploreConfig(numRuns: 150)).test(
      'offers exactly the missing kind of each entry, at most once',
      (media) {
        final entries = [
          for (var i = 0; i < media.length; i++) _entity(media[i], i),
        ];
        final responses = {
          for (var i = 0; i < media.length; i++)
            entries[i].meta.id: _responses(media[i]),
        };

        final candidates = findMissingInference(entries, responses);

        final expected = {
          for (var i = 0; i < media.length; i++)
            entries[i].meta.id: ?_expectedKind(media[i]),
        };
        expect(
          {for (final c in candidates) c.entryId: c.kind},
          expected,
        );
        expect(candidates, hasLength(expected.length));
        for (var i = 1; i < candidates.length; i++) {
          expect(
            candidates[i - 1].capturedAt.isBefore(candidates[i].capturedAt),
            isFalse,
          );
        }
      },
      tags: 'glados',
    );
  });

  group('InferenceBackfillKind', () {
    test('maps each tool name back to its kind', () {
      for (final kind in InferenceBackfillKind.values) {
        expect(InferenceBackfillKind.fromToolName(kind.toolName), kind);
      }
      expect(InferenceBackfillKind.fromToolName('set_task_title'), isNull);
    });

    test('runs the matching skill type', () {
      expect(
        InferenceBackfillKind.values.map((kind) => kind.skillType),
        [
          SkillType.imageAnalysis,
          SkillType.transcription,
          SkillType.audioSummary,
        ],
      );
    });

    test('an audio entry is busy while either of its kinds runs', () {
      const audioTypes = {
        AiResponseType.audioTranscription,
        AiResponseType.audioSummary,
      };
      expect(InferenceBackfillKind.transcription.busyResponseTypes, audioTypes);
      expect(InferenceBackfillKind.audioSummary.busyResponseTypes, audioTypes);
      expect(InferenceBackfillKind.imageAnalysis.busyResponseTypes, {
        AiResponseType.imageAnalysis,
      });
    });
  });

  group('InferenceBackfillCandidate', () {
    final candidate = InferenceBackfillCandidate(
      entryId: 'e',
      kind: InferenceBackfillKind.transcription,
      capturedAt: testFixedDate,
    );

    test('is keyed by kind and entry', () {
      expect(candidate.key, 'transcription:e');
      expect(candidate.toString(), contains('transcription:e'));
    });

    test('equals a candidate with the same fields only', () {
      expect(
        candidate,
        InferenceBackfillCandidate(
          entryId: 'e',
          kind: InferenceBackfillKind.transcription,
          capturedAt: testFixedDate,
        ),
      );
      expect(
        candidate.hashCode,
        InferenceBackfillCandidate(
          entryId: 'e',
          kind: InferenceBackfillKind.transcription,
          capturedAt: testFixedDate,
        ).hashCode,
      );
      expect(
        candidate,
        isNot(
          InferenceBackfillCandidate(
            entryId: 'e',
            kind: InferenceBackfillKind.audioSummary,
            capturedAt: testFixedDate,
          ),
        ),
      );
    });
  });
}
