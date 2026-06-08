import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list_item.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';
import 'test_utils.dart';

// ---------------------------------------------------------------------------
// Fake controller
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _now = DateTime(2024, 3, 15, 9);

JournalAudio _makeAudio({List<AudioTranscript>? transcripts}) {
  return JournalAudio(
    meta: Metadata(
      id: 'audio-99',
      createdAt: _now,
      updatedAt: _now,
      dateFrom: _now,
      dateTo: _now,
    ),
    data: AudioData(
      dateFrom: _now,
      dateTo: _now,
      audioFile: 'rec.m4a',
      audioDirectory: '/audio',
      duration: const Duration(minutes: 2),
      transcripts: transcripts,
    ),
  );
}

AudioTranscript _makeTranscript(String text) {
  return AudioTranscript(
    created: _now,
    library: 'whisper',
    model: 'ggml-small.bin',
    detectedLanguage: 'en',
    transcript: text,
  );
}

JournalEntry _makeJournalEntry() {
  return JournalEntry(
    meta: Metadata(
      id: 'text-1',
      createdAt: _now,
      updatedAt: _now,
      dateFrom: _now,
      dateTo: _now,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  JournalEntity? entry,
  String entryId = 'audio-99',
}) async {
  final ctrl = FakeEntryController(entry);

  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      TranscriptsList(entryId: entryId),
      overrides: [
        entryControllerProvider(id: entryId).overrideWith(() => ctrl),
      ],
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final mockCache = MockEntitiesCacheService();
        when(() => mockCache.getCategoryById(any())).thenReturn(null);
        when(() => mockCache.showPrivateEntries).thenReturn(true);
        getIt
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );
  });
  tearDownAll(tearDownTestGetIt);

  group('TranscriptsList', () {
    testWidgets('renders nothing when entry state is null', (tester) async {
      await _pump(tester);

      expect(find.byType(TranscriptListItem), findsNothing);
    });

    testWidgets(
      'renders nothing when entry is not JournalAudio',
      (tester) async {
        await _pump(tester, entry: _makeJournalEntry(), entryId: 'text-1');

        expect(find.byType(TranscriptListItem), findsNothing);
      },
    );

    testWidgets(
      'renders no TranscriptListItems when transcripts list is null',
      (tester) async {
        await _pump(tester, entry: _makeAudio());

        expect(find.byType(TranscriptListItem), findsNothing);
      },
    );

    testWidgets(
      'renders no TranscriptListItems when transcripts list is empty',
      (tester) async {
        await _pump(tester, entry: _makeAudio(transcripts: []));

        // An empty (non-null) list must collapse to no items without crashing.
        expect(find.byType(TranscriptListItem), findsNothing);

        // The JournalAudio branch is still taken (not the SizedBox.shrink()
        // collapse used for null/non-audio entries): its Column shell with the
        // leading 10px spacer renders.
        final shell = find.descendant(
          of: find.byType(TranscriptsList),
          matching: find.byType(Column),
        );
        expect(shell, findsOneWidget);
      },
    );

    testWidgets(
      'renders one TranscriptListItem per transcript',
      (tester) async {
        final entry = _makeAudio(
          transcripts: [
            _makeTranscript('Hello world'),
            _makeTranscript('Second transcript'),
          ],
        );

        await _pump(tester, entry: entry);

        expect(find.byType(TranscriptListItem), findsNWidgets(2));
      },
    );

    testWidgets(
      'renders exactly one TranscriptListItem for a single transcript',
      (tester) async {
        final entry = _makeAudio(
          transcripts: [_makeTranscript('Only one')],
        );

        await _pump(tester, entry: entry);

        expect(find.byType(TranscriptListItem), findsOneWidget);
      },
    );
  });
}
