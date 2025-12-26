import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list_item.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TranscriptListItem Tests', () {
    late MockJournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;

    setUpAll(() {
      final now = DateTime(2025, 1, 21, 13, 9);
      registerFallbackValue(
        Metadata(
          id: 'test-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
      );
      registerFallbackValue(
        JournalAudio(
          meta: Metadata(
            id: 'test-id',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: AudioData(
            audioDirectory: '/test',
            duration: const Duration(seconds: 1),
            audioFile: 'test.m4a',
            dateTo: now,
            dateFrom: now,
          ),
        ),
      );
    });

    setUp(() async {
      mockJournalDb = MockJournalDb();
      mockPersistenceLogic = MockPersistenceLogic();

      await getIt.reset();
      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });

    tearDown(() async {
      await getIt.reset();
    });
    final testTranscript = AudioTranscript(
      created: DateTime(2025, 1, 21, 13, 9),
      library: 'Gemini',
      model: 'models/gemini-2.5-flash-preview-04-17',
      detectedLanguage: 'en',
      transcript: 'The other task is to do some testing of the synchronization '
          'from mobile to desktop in my test instance.',
      processingTime: const Duration(seconds: 6),
    );

    final testTranscriptNoProcessingTime = AudioTranscript(
      created: DateTime(2025, 1, 21, 13, 9),
      library: 'Whisper',
      model: 'ggml-small.bin',
      detectedLanguage: 'de',
      transcript: 'Test transcript without processing time',
    );

    final testTranscriptLongModel = AudioTranscript(
      created: DateTime(2025, 1, 21, 13, 9),
      library: 'Gemini',
      model:
          'models/gemini-2.5-flash-preview-04-17-very-long-model-name-that-should-overflow',
      detectedLanguage: 'fr',
      transcript: 'Test transcript with very long model name',
      processingTime: const Duration(minutes: 1, seconds: 30),
    );

    Widget makeTestableWidget(AudioTranscript transcript) {
      return makeTestableWidgetWithScaffold(
        TranscriptListItem(
          transcript,
          entryId: 'test-entry-id',
        ),
      );
    }

    testWidgets('renders correctly with transcript data', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      expect(find.byType(TranscriptListItem), findsOneWidget);
      expect(find.byType(ExpansionTile), findsOneWidget);

      // Check that language is displayed
      expect(find.textContaining('Lang: EN'), findsOneWidget);

      // Check that model is displayed
      expect(find.textContaining('Model: Gemini'), findsOneWidget);

      // Expand to see the transcript text
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_down_outlined));
      await tester.pumpAndSettle();

      // Check that the transcript text is present after expansion
      expect(
        find.text(
          'The other task is to do some testing of the synchronization '
          'from mobile to desktop in my test instance.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('has correct horizontal padding', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      final expansionTile = tester.widget<ExpansionTile>(
        find.byType(ExpansionTile),
      );

      expect(expansionTile.tilePadding,
          const EdgeInsets.symmetric(horizontal: 16));
    });

    testWidgets('trailing buttons have width constraint', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      final expansionTile = tester.widget<ExpansionTile>(
        find.byType(ExpansionTile),
      );

      // Check that trailing is wrapped in a SizedBox with width constraint
      expect(expansionTile.trailing, isA<SizedBox>());
      final sizedBox = expansionTile.trailing! as SizedBox;
      expect(sizedBox.width, 96);
    });

    testWidgets('title uses Column layout structure', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      final expansionTile = tester.widget<ExpansionTile>(
        find.byType(ExpansionTile),
      );

      // Check that title is a Column
      expect(expansionTile.title, isA<Column>());
      final column = expansionTile.title as Column;

      // Check that the Column has CrossAxisAlignment.start
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);

      // Check that the Column has 2 Row children (timestamp + processing time, lang + model)
      expect(column.children.whereType<Row>().length, 2);
    });

    testWidgets('displays processing time when available', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Check for processing time emoji and formatted time
      expect(find.textContaining('⏳'), findsOneWidget);
      expect(find.textContaining('00m06s'), findsOneWidget);
    });

    testWidgets('does not display processing time when not available',
        (tester) async {
      await tester
          .pumpWidget(makeTestableWidget(testTranscriptNoProcessingTime));
      await tester.pumpAndSettle();

      // Check that processing time is not shown
      expect(find.textContaining('⏳'), findsNothing);
    });

    testWidgets('toggle button expands and collapses transcript',
        (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Initially collapsed - should show down arrow
      expect(
        find.byIcon(Icons.keyboard_double_arrow_down_outlined),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.keyboard_double_arrow_up_outlined),
        findsNothing,
      );

      // Tap to expand
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_down_outlined));
      await tester.pumpAndSettle();

      // Should now show up arrow
      expect(
        find.byIcon(Icons.keyboard_double_arrow_up_outlined),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.keyboard_double_arrow_down_outlined),
        findsNothing,
      );

      // Tap to collapse
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_up_outlined));
      await tester.pumpAndSettle();

      // Should show down arrow again
      expect(
        find.byIcon(Icons.keyboard_double_arrow_down_outlined),
        findsOneWidget,
      );
    });

    testWidgets('delete button is hidden initially', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Find the Opacity widget containing the delete button
      final opacityFinder = find.ancestor(
        of: find.byIcon(MdiIcons.trashCanOutline),
        matching: find.byType(Opacity),
      );

      expect(opacityFinder, findsOneWidget);

      final opacity = tester.widget<Opacity>(opacityFinder);
      expect(opacity.opacity, 0);
    });

    testWidgets('delete button is visible when expanded', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_down_outlined));
      await tester.pumpAndSettle();

      // Find the Opacity widget containing the delete button
      final opacityFinder = find.ancestor(
        of: find.byIcon(MdiIcons.trashCanOutline),
        matching: find.byType(Opacity),
      );

      expect(opacityFinder, findsOneWidget);

      final opacity = tester.widget<Opacity>(opacityFinder);
      expect(opacity.opacity, 1);
    });

    testWidgets('icon buttons have zero padding and minimal constraints',
        (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Find all IconButtons
      final iconButtons = tester.widgetList<IconButton>(
        find.byType(IconButton),
      );

      // All icon buttons should have zero padding and minimal constraints
      for (final button in iconButtons) {
        expect(button.padding, EdgeInsets.zero);
        expect(button.constraints,
            const BoxConstraints(minWidth: 40, minHeight: 40));
      }
    });

    testWidgets('handles long model names with Flexible and ellipsis',
        (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscriptLongModel));
      await tester.pumpAndSettle();

      // Find the Flexible widget containing the model text
      final flexibleFinder = find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.byType(Flexible),
      );

      expect(flexibleFinder, findsOneWidget);

      // Check that the Text inside Flexible has ellipsis overflow
      final textFinder = find.descendant(
        of: flexibleFinder,
        matching: find.byType(Text),
      );

      expect(textFinder, findsOneWidget);

      final text = tester.widget<Text>(textFinder);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('transcript content has correct padding', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Expand to show content
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_down_outlined));
      await tester.pumpAndSettle();

      // Find the direct Padding widget containing SelectableText
      final selectableText = find.byType(SelectableText);
      expect(selectableText, findsOneWidget);

      // Get the parent Padding widget - it should be the immediate parent
      final paddingFinder = find.ancestor(
        of: selectableText,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding ==
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      );

      expect(paddingFinder, findsOneWidget);
    });

    testWidgets('formats duration correctly', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscriptLongModel));
      await tester.pumpAndSettle();

      // Check that the processing time is formatted as mm:ss
      expect(find.text('⏳01m30s'), findsOneWidget);
    });

    testWidgets('displays different languages correctly', (tester) async {
      await tester
          .pumpWidget(makeTestableWidget(testTranscriptNoProcessingTime));
      await tester.pumpAndSettle();

      // Check that German language is displayed in uppercase
      expect(find.textContaining('Lang: DE'), findsOneWidget);

      await tester.pumpWidget(makeTestableWidget(testTranscriptLongModel));
      await tester.pumpAndSettle();

      // Check that French language is displayed in uppercase
      expect(find.textContaining('Lang: FR'), findsOneWidget);
    });

    testWidgets('language and model info are on the same row', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      final expansionTile = tester.widget<ExpansionTile>(
        find.byType(ExpansionTile),
      );

      final column = expansionTile.title as Column;
      final rows = column.children.whereType<Row>().toList();

      // Second row should contain both language and model info
      expect(rows[1].children.length, greaterThan(1));

      // Find Text widgets in the second row
      final textWidgets = <Text>[];
      void findTextWidgets(Widget widget) {
        if (widget is Text) {
          textWidgets.add(widget);
        } else if (widget is Row) {
          widget.children.forEach(findTextWidgets);
        } else if (widget is Flexible) {
          findTextWidgets(widget.child);
        }
      }

      findTextWidgets(rows[1]);

      // Should have at least 2 text widgets (lang and model)
      expect(textWidgets.length, greaterThanOrEqualTo(2));
    });

    testWidgets('transcript is selectable', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Expand to show content
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_down_outlined));
      await tester.pumpAndSettle();

      // Check that transcript uses SelectableText
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('timestamp is displayed correctly', (tester) async {
      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Check that the date is formatted and displayed
      // Using a partial match since dfShorter format may vary
      expect(find.textContaining('2025'), findsOneWidget);
    });

    testWidgets('maintains layout integrity with multiple transcripts',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Column(
            children: [
              TranscriptListItem(
                testTranscript,
                entryId: 'test-entry-1',
              ),
              TranscriptListItem(
                testTranscriptNoProcessingTime,
                entryId: 'test-entry-2',
              ),
              TranscriptListItem(
                testTranscriptLongModel,
                entryId: 'test-entry-3',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All three transcripts should render
      expect(find.byType(TranscriptListItem), findsNWidgets(3));
      expect(find.byType(ExpansionTile), findsNWidgets(3));

      // Each should have their own toggle button
      expect(
        find.byIcon(Icons.keyboard_double_arrow_down_outlined),
        findsNWidgets(3),
      );
    });

    testWidgets('tapping delete button triggers deletion', (tester) async {
      const entryId = 'test-entry-id';
      final now = DateTime(2025, 1, 21, 13, 9);

      // Create a JournalAudio entity with transcripts
      final audioData = AudioData(
        audioDirectory: '/test/path',
        duration: const Duration(seconds: 10),
        audioFile: 'test.m4a',
        dateTo: now.add(const Duration(seconds: 10)),
        dateFrom: now,
        language: 'en',
        transcripts: [
          testTranscript,
          AudioTranscript(
            created: DateTime(2025, 1, 21, 14),
            library: 'Whisper',
            model: 'small',
            detectedLanguage: 'en',
            transcript: 'Another transcript',
          ),
        ],
      );

      final journalAudio = JournalAudio(
        meta: Metadata(
          id: entryId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(seconds: 10)),
        ),
        data: audioData,
      );

      // Mock journalEntityById to return the entity
      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalAudio);

      // Mock updateMetadata to return updated metadata
      when(() => mockPersistenceLogic.updateMetadata(any()))
          .thenAnswer((invocation) async {
        final meta = invocation.positionalArguments[0] as Metadata;
        return meta.copyWith(updatedAt: DateTime.now());
      });

      // Mock updateDbEntity
      when(() => mockPersistenceLogic.updateDbEntity(any()))
          .thenAnswer((_) async {
        return null;
      });

      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Expand to show delete button
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_down_outlined));
      await tester.pumpAndSettle();

      // Tap the delete button
      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pumpAndSettle();

      // Verify that updateDbEntity was called
      final captured = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured;

      expect(captured, hasLength(1));

      final updatedEntity = captured.first as JournalAudio;
      // The updated entity should not contain testTranscript
      expect(
        updatedEntity.data.transcripts
            ?.any((t) => t.created == testTranscript.created),
        false,
      );
      // But should still contain the other transcript
      expect(updatedEntity.data.transcripts?.length, 1);
    });

    testWidgets('hidden delete button does not respond to taps',
        (tester) async {
      const entryId = 'test-entry-id';
      final now = DateTime(2025, 1, 21, 13, 9);

      final audioData = AudioData(
        audioDirectory: '/test/path',
        duration: const Duration(seconds: 10),
        audioFile: 'test.m4a',
        dateTo: now.add(const Duration(seconds: 10)),
        dateFrom: now,
        language: 'en',
        transcripts: [testTranscript],
      );

      final journalAudio = JournalAudio(
        meta: Metadata(
          id: entryId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(seconds: 10)),
        ),
        data: audioData,
      );

      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => journalAudio);

      when(() => mockPersistenceLogic.updateMetadata(any()))
          .thenAnswer((invocation) async {
        final meta = invocation.positionalArguments[0] as Metadata;
        return meta.copyWith(updatedAt: DateTime.now());
      });

      when(() => mockPersistenceLogic.updateDbEntity(any()))
          .thenAnswer((_) async {
        return null;
      });

      await tester.pumpWidget(makeTestableWidget(testTranscript));
      await tester.pumpAndSettle();

      // Delete button is hidden (opacity 0) but still in widget tree
      // Try to tap at the position where the delete button is
      final deleteButtonFinder = find.byIcon(MdiIcons.trashCanOutline);
      expect(deleteButtonFinder, findsOneWidget);

      // Try to tap the hidden button (warnIfMissed: false since we know it's hidden)
      await tester.tap(deleteButtonFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify that updateDbEntity was NOT called
      verifyNever(() => mockPersistenceLogic.updateDbEntity(any()));
    });
  });
}
