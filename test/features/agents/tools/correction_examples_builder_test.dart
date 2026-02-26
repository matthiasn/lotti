import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/correction_examples_builder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  late MockJournalDb mockDb;
  late Task task;

  setUp(() {
    mockDb = MockJournalDb();
    task = testTask.copyWith(
      meta: testTask.meta.copyWith(categoryId: 'cat-1'),
    );
  });

  group('CorrectionExamplesBuilder', () {
    group('buildContext', () {
      test('returns empty string when task has no categoryId', () async {
        final noCatTask = task.copyWith(
          meta: task.meta.copyWith(categoryId: null),
        );

        final result = await CorrectionExamplesBuilder.buildContext(
          task: noCatTask,
          journalDb: mockDb,
        );

        expect(result, isEmpty);
        verifyNever(() => mockDb.getCategoryById(any()));
      });

      test('returns empty string when category not found', () async {
        when(() => mockDb.getCategoryById('cat-1'))
            .thenAnswer((_) async => null);

        final result = await CorrectionExamplesBuilder.buildContext(
          task: task,
          journalDb: mockDb,
        );

        expect(result, isEmpty);
      });

      test('returns empty string when category has no examples', () async {
        when(() => mockDb.getCategoryById('cat-1')).thenAnswer(
          (_) async => categoryMindfulness.copyWith(
            id: 'cat-1',
            correctionExamples: null,
          ),
        );

        final result = await CorrectionExamplesBuilder.buildContext(
          task: task,
          journalDb: mockDb,
        );

        expect(result, isEmpty);
      });

      test('returns empty string when examples list is empty', () async {
        when(() => mockDb.getCategoryById('cat-1')).thenAnswer(
          (_) async => categoryMindfulness.copyWith(
            id: 'cat-1',
            correctionExamples: const [],
          ),
        );

        final result = await CorrectionExamplesBuilder.buildContext(
          task: task,
          journalDb: mockDb,
        );

        expect(result, isEmpty);
      });

      test('returns formatted examples from category', () async {
        when(() => mockDb.getCategoryById('cat-1')).thenAnswer(
          (_) async => categoryMindfulness.copyWith(
            id: 'cat-1',
            correctionExamples: [
              ChecklistCorrectionExample(
                before: 'teh mistake',
                after: 'the mistake',
                capturedAt: DateTime(2024, 6),
              ),
            ],
          ),
        );

        final result = await CorrectionExamplesBuilder.buildContext(
          task: task,
          journalDb: mockDb,
        );

        expect(result, contains('## Correction Examples'));
        expect(result, contains('teh mistake'));
        expect(result, contains('the mistake'));
      });
    });

    group('formatExamples', () {
      test('returns empty string for null examples', () {
        expect(CorrectionExamplesBuilder.formatExamples(null), isEmpty);
      });

      test('returns empty string for empty examples', () {
        expect(CorrectionExamplesBuilder.formatExamples(const []), isEmpty);
      });

      test('formats single example correctly', () {
        final result = CorrectionExamplesBuilder.formatExamples([
          const ChecklistCorrectionExample(
            before: 'orignal',
            after: 'original',
          ),
        ]);

        expect(result, contains('## Correction Examples'));
        expect(result, contains('transcription errors'));
        expect(result, contains('- "orignal" → "original"'));
      });

      test('sorts by capturedAt descending (most recent first)', () {
        final result = CorrectionExamplesBuilder.formatExamples([
          ChecklistCorrectionExample(
            before: 'old',
            after: 'old-fixed',
            capturedAt: DateTime(2024),
          ),
          ChecklistCorrectionExample(
            before: 'new',
            after: 'new-fixed',
            capturedAt: DateTime(2024, 6),
          ),
          ChecklistCorrectionExample(
            before: 'mid',
            after: 'mid-fixed',
            capturedAt: DateTime(2024, 3),
          ),
        ]);

        // Most recent should appear first.
        final newIdx = result.indexOf('new');
        final midIdx = result.indexOf('mid');
        final oldIdx = result.indexOf('old-fixed');
        expect(newIdx, lessThan(midIdx));
        expect(midIdx, lessThan(oldIdx));
      });

      test('caps at maxExamples', () {
        final examples = List.generate(
          60,
          (i) => ChecklistCorrectionExample(
            before: 'before-$i',
            after: 'after-$i',
            capturedAt: DateTime(2024, 1, 1, i),
          ),
        );

        final result = CorrectionExamplesBuilder.formatExamples(examples);

        // Should only contain the 50 most recent (i=59 down to i=10).
        expect(result, contains('before-59'));
        expect(result, contains('before-10'));
        // i=9 should be excluded (51st oldest).
        expect(result, isNot(contains('before-9')));
      });

      test('escapes double quotes in before and after', () {
        final result = CorrectionExamplesBuilder.formatExamples([
          const ChecklistCorrectionExample(
            before: 'say "hello"',
            after: 'say "hi"',
          ),
        ]);

        expect(result, contains(r'say \"hello\"'));
        expect(result, contains(r'say \"hi\"'));
      });

      test('handles examples without capturedAt', () {
        final result = CorrectionExamplesBuilder.formatExamples([
          const ChecklistCorrectionExample(
            before: 'no-date',
            after: 'no-date-fixed',
          ),
          ChecklistCorrectionExample(
            before: 'has-date',
            after: 'has-date-fixed',
            capturedAt: DateTime(2024, 6),
          ),
        ]);

        // Example with date should come first (more recent than fallback).
        final hasDateIdx = result.indexOf('has-date');
        final noDateIdx = result.indexOf('no-date');
        expect(hasDateIdx, lessThan(noDateIdx));
      });

      test('maxExamples constant is 50', () {
        expect(CorrectionExamplesBuilder.maxExamples, equals(50));
      });
    });
  });
}
