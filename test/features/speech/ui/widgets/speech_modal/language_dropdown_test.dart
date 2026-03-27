import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/language_dropdown.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';

import '../../../../../helpers/fake_entry_controller.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2025, 6, 15, 12);

  JournalAudio buildAudio({String language = ''}) {
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
        duration: const Duration(seconds: 30),
        audioFile: 'test.aac',
        audioDirectory: '/tmp',
        language: language,
      ),
    );
  }

  setUp(() async {
    await setUpTestGetIt();
    getIt.registerSingleton<EditorStateService>(MockEditorStateService());
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String language = '',
    ToggleCallTracker? tracker,
  }) {
    final audio = buildAudio(language: language);
    final controller = FakeEntryController(audio, tracker: tracker);

    return makeTestableWidgetWithScaffold(
      const LanguageDropdown(entryId: 'audio-1'),
      overrides: [
        entryControllerProvider(id: 'audio-1').overrideWith(
          () => controller,
        ),
      ],
    );
  }

  group('LanguageDropdown', () {
    testWidgets('renders DesignSystemDropdown with auto label', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemDropdown), findsOneWidget);
      expect(find.text('auto'), findsOneWidget);
    });

    testWidgets('shows English when en is selected', (tester) async {
      await tester.pumpWidget(buildSubject(language: 'en'));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('shows German when de is selected', (tester) async {
      await tester.pumpWidget(buildSubject(language: 'de'));
      await tester.pumpAndSettle();

      expect(find.text('German'), findsOneWidget);
    });

    testWidgets('calls setLanguage when an item is tapped', (tester) async {
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(buildSubject(tracker: tracker));
      await tester.pumpAndSettle();

      // Tap the dropdown trigger to expand it
      await tester.tap(find.byType(DesignSystemDropdown));
      await tester.pumpAndSettle();

      // Tap the 'English' menu item
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(tracker.setLanguageCalls, ['en']);
    });

    testWidgets('renders nothing when entry is not JournalAudio', (
      tester,
    ) async {
      final textEntry = JournalEntry(
        meta: Metadata(
          id: 'text-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
      );
      final controller = FakeEntryController(textEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const LanguageDropdown(entryId: 'text-1'),
          overrides: [
            entryControllerProvider(id: 'text-1').overrideWith(
              () => controller,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesignSystemDropdown), findsNothing);
    });
  });
}
