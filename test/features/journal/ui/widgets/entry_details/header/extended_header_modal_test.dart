import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/speech_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_data/test_data.dart';
import '../../../../../../widget_test_utils.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this._entry);

  final JournalEntity _entry;

  @override
  Future<EntryState?> build() async {
    return EntryState.saved(
      entryId: id,
      entry: _entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final cacheService = MockEntitiesCacheService();
    final journalDb = MockJournalDb();
    final updateNotifications = MockUpdateNotifications();

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(() => cacheService.getLabelById(any())).thenReturn(null);
    when(() => updateNotifications.updateStream).thenAnswer(
      (_) => const Stream.empty(),
    );

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(MockEditorStateService())
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LinkService>(MockLinkService());
  });

  tearDown(getIt.reset);

  Future<void> pumpAndOpenModal(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryControllerProvider(
            testAudioEntry.meta.id,
          ).overrideWith(() => _TestEntryController(testAudioEntry)),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value([]),
          ),
        ],
        child: makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => ExtendedHeaderModal.show(
                context: context,
                entryId: testAudioEntry.meta.id,
                linkedFromId: null,
                link: null,
                inLinkedEntries: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    // Modal entrance animation — settle is genuinely required.
    await tester.pumpAndSettle();
  }

  group('ExtendedHeaderModal', () {
    testWidgets('opens on the initial actions page', (tester) async {
      await pumpAndOpenModal(tester);

      expect(find.byType(InitialModalPageContent), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.byType(SpeechModalContent), findsNothing);
    });

    testWidgets(
      'tapping the speech item switches to the speech recognition page '
      'and the back button returns to page 0',
      (tester) async {
        await pumpAndOpenModal(tester);

        // The audio entry exposes the speech action; tapping it flips the
        // shared pageIndexNotifier to 1.
        await tester.tap(find.byIcon(Icons.transcribe_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(SpeechModalContent), findsOneWidget);
        expect(find.byType(InitialModalPageContent), findsNothing);

        // The speech page's back button resets the notifier to 0.
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(InitialModalPageContent), findsOneWidget);
        expect(find.byType(SpeechModalContent), findsNothing);
      },
    );
  });
}
