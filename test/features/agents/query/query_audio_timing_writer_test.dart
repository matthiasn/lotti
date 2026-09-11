import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/query/query_audio_timing_writer.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import 'query_audio_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  late MockJournalDb journal;
  late MockPersistenceLogic persistence;
  late QueryAudioTimingWriter writer;
  final original = testAudioEntryWithTranscripts;
  setUp(() {
    journal = MockJournalDb();
    persistence = MockPersistenceLogic();
    writer = QueryAudioTimingWriter(journal: journal, persistence: persistence);
    when(
      () => journal.journalEntityById(original.id),
    ).thenAnswer((_) async => original);
    when(
      () => persistence.updateMetadata(any()),
    ).thenAnswer((_) async => original.meta);
    when(() => persistence.updateDbEntity(any())).thenAnswer((_) async => true);
  });
  test(
    'adds only timing while preserving source wording, privacy and transcripts',
    () async {
      expect(
        await writer.save(
          expected: original,
          timing: audioTiming(),
          isCancelled: () => false,
        ),
        isTrue,
      );
      final saved =
          verify(() => persistence.updateDbEntity(captureAny())).captured.single
              as JournalAudio;
      expect(
        saved,
        original.copyWith(
          data: original.data.copyWith(transcriptTiming: audioTiming()),
        ),
      );
      expect(saved.meta.private, original.meta.private);
      expect(saved.data.transcripts, original.data.transcripts);
      expect(saved.entryText, original.entryText);
    },
  );
  test(
    'rejects deleted, edited, replaced or missing sources without a write',
    () async {
      for (final source in <JournalEntity?>[
        null,
        testTextEntry,
        original.copyWith(meta: original.meta.copyWith(private: true)),
        original.copyWith(
          meta: original.meta.copyWith(deletedAt: DateTime(2026, 7, 17)),
        ),
        original.copyWith(
          data: original.data.copyWith(audioFile: 'replaced.m4a'),
        ),
      ]) {
        when(
          () => journal.journalEntityById(original.id),
        ).thenAnswer((_) async => source);
        expect(
          await writer.save(
            expected: original,
            timing: audioTiming(),
            isCancelled: () => false,
          ),
          isFalse,
        );
      }
      verifyNever(() => persistence.updateDbEntity(any()));
    },
  );
  test(
    'cancellation before and during metadata preparation prevents persistence',
    () async {
      expect(
        await writer.save(
          expected: original,
          timing: audioTiming(),
          isCancelled: () => true,
        ),
        isFalse,
      );
      final pending = Completer<Metadata>();
      final entered = Completer<void>();
      when(() => persistence.updateMetadata(any())).thenAnswer((_) {
        entered.complete();
        return pending.future;
      });
      var cancelled = false;
      final save = writer.save(
        expected: original,
        timing: audioTiming(),
        isCancelled: () => cancelled,
      );
      await entered.future;
      cancelled = true;
      pending.complete(original.meta);
      expect(await save, isFalse);
      verifyNever(() => persistence.updateDbEntity(any()));
    },
  );
  test('reports a rejected persistence write', () async {
    when(
      () => persistence.updateDbEntity(any()),
    ).thenAnswer((_) async => false);
    expect(
      await writer.save(
        expected: original,
        timing: audioTiming(),
        isCancelled: () => false,
      ),
      isFalse,
    );
  });
}
