import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/language_dropdown.dart';
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

JournalAudio _makeAudioEntry({String language = ''}) {
  final now = DateTime(2024, 3, 15);
  return JournalAudio(
    meta: Metadata(
      id: 'audio-1',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: AudioData(
      dateFrom: now,
      dateTo: now,
      audioFile: 'rec.m4a',
      audioDirectory: '/audio',
      duration: const Duration(seconds: 60),
      language: language,
    ),
  );
}

JournalEntry _makeJournalEntry() {
  final now = DateTime(2024, 3, 15);
  return JournalEntry(
    meta: Metadata(
      id: 'text-1',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
  );
}

Future<FakeEntryController> _pump(
  WidgetTester tester, {
  JournalEntity? entry,
}) async {
  final ctrl = FakeEntryController(entry);
  final entryId = entry?.id ?? 'audio-1';

  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      LanguageDropdown(entryId: entryId),
      overrides: [
        entryControllerProvider(id: entryId).overrideWith(() => ctrl),
      ],
    ),
  );
  await tester.pump();
  return ctrl;
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

  group('LanguageDropdown', () {
    testWidgets(
      'renders nothing when entry state is null',
      (tester) async {
        await _pump(tester);

        expect(find.byType(DropdownButton<String>), findsNothing);
      },
    );

    testWidgets(
      'renders nothing when entry is not JournalAudio',
      (tester) async {
        await _pump(tester, entry: _makeJournalEntry());

        expect(find.byType(DropdownButton<String>), findsNothing);
      },
    );

    testWidgets(
      'renders DropdownButton for a JournalAudio entry',
      (tester) async {
        await _pump(tester, entry: _makeAudioEntry(language: 'en'));

        expect(find.byType(DropdownButton<String>), findsOneWidget);
      },
    );

    testWidgets(
      'shows language selection label text',
      (tester) async {
        // ignore: avoid_redundant_argument_values
        await _pump(tester, entry: _makeAudioEntry(language: ''));

        // The language label from localization is present
        expect(find.text('auto'), findsWidgets);
      },
    );

    testWidgets(
      'shows "English" as selected when language is en',
      (tester) async {
        await _pump(tester, entry: _makeAudioEntry(language: 'en'));

        // The currently selected item value is 'en', rendered as "English"
        expect(find.text('English'), findsWidgets);
      },
    );

    testWidgets(
      'shows "Deutsch" as option when language is de',
      (tester) async {
        await _pump(tester, entry: _makeAudioEntry(language: 'de'));

        expect(find.text('Deutsch'), findsWidgets);
      },
    );

    testWidgets(
      'calls setLanguage when a different language is selected',
      (tester) async {
        // ignore: avoid_redundant_argument_values
        final ctrl = await _pump(tester, entry: _makeAudioEntry(language: ''));

        // Open the dropdown
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pump();

        // Tap "English" option
        await tester.tap(find.text('English').last);
        await tester.pump();

        expect(ctrl.setLanguageCalls, contains('en'));
      },
    );
  });
}
