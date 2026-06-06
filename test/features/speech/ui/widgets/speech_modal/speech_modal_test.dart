import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/language_dropdown.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/speech_modal.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list_item.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';

import '../../../../../helpers/fake_entry_controller.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

/// Records the language codes forwarded by the dropdown.
class _LanguageRecordingEntryController extends FakeEntryController {
  _LanguageRecordingEntryController(super._entity);

  final List<String> setLanguageCalls = [];

  @override
  Future<void> setLanguage(String language) async {
    setLanguageCalls.add(language);
  }
}

void main() {
  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        // EntryController's constructor resolves EditorStateService eagerly.
        getIt.registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Future<_LanguageRecordingEntryController> pumpModal(
    WidgetTester tester, {
    required JournalEntity entity,
  }) async {
    final controller = _LanguageRecordingEntryController(entity);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryControllerProvider(
            id: entity.meta.id,
          ).overrideWith(() => controller),
        ],
        child: makeTestableWidgetWithScaffold(
          SpeechModalContent(entryId: entity.meta.id),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  group('SpeechModalContent', () {
    testWidgets(
      'renders the language dropdown and the transcript rows for an '
      'audio entry',
      (tester) async {
        await pumpModal(tester, entity: testAudioEntryWithTranscripts);

        // Language selector with its localized label and the dropdown.
        expect(find.byType(LanguageDropdown), findsOneWidget);
        expect(find.byType(DropdownButton<String>), findsOneWidget);

        // One transcript row per stored transcript, showing its model name.
        final transcripts = testAudioEntryWithTranscripts.data.transcripts!;
        expect(
          find.byType(TranscriptListItem),
          findsNWidgets(transcripts.length),
        );
        final first = transcripts.first;
        expect(
          find.text('Lang: ${first.detectedLanguage.toUpperCase()}'),
          findsOneWidget,
        );
        expect(
          find.text('Model: ${first.library}, ${first.model}'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'selecting a language forwards the code to the entry controller',
      (tester) async {
        final controller = await pumpModal(
          tester,
          entity: testAudioEntryWithTranscripts,
        );

        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Deutsch').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.setLanguageCalls, ['de']);
      },
    );

    testWidgets(
      'collapses to nothing when the entry is not an audio entry',
      (tester) async {
        await pumpModal(tester, entity: testTextEntry);

        expect(find.byType(TranscriptsList), findsOneWidget);
        expect(find.byType(DropdownButton<String>), findsNothing);
        expect(find.byType(TranscriptListItem), findsNothing);
      },
    );
  });
}
