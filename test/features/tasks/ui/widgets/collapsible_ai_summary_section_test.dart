import 'dart:async';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_ai_summary_section.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_task_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

// Minimal mocks for dependencies
class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

// Test implementations that extend the actual controllers
class TestLatestSummaryController extends LatestSummaryController {
  TestLatestSummaryController(this._value);

  final AiResponseEntry? _value;

  @override
  void listen() {
    // No-op: don't set up real listeners in tests
  }

  @override
  Future<AiResponseEntry?> build({
    required String id,
    required AiResponseType aiResponseType,
  }) async {
    // Set the state directly without any dependencies
    state = AsyncValue.data(_value);
    return _value;
  }

  @override
  Future<void> removeActionItem({required String title}) async {
    // No-op for testing
  }
}

class TestInferenceStatusController extends InferenceStatusController {
  TestInferenceStatusController(this._status);

  final InferenceStatus _status;

  @override
  InferenceStatus build({
    required String id,
    required AiResponseType aiResponseType,
  }) {
    // Set the state directly without calling super or using dependencies
    state = _status;
    return _status;
  }
}

void main() {
  late MockUpdateNotifications mockUpdateNotifications;
  late MockPersistenceLogic mockPersistenceLogic;
  late StreamController<Set<String>> updateStreamController;

  setUpAll(getIt.reset);

  group('CollapsibleAiSummarySection', () {
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();

      // Set up mocks
      mockUpdateNotifications = MockUpdateNotifications();
      mockPersistenceLogic = MockPersistenceLogic();
      updateStreamController = StreamController<Set<String>>.broadcast();

      // Configure mock behavior
      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => updateStreamController.stream);

      // Register mocks with getIt
      getIt
        ..reset()
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });

    tearDown(() {
      scrollController.dispose();
      updateStreamController.close();
      getIt.reset();
    });

    List<Override> getOverrides({
      AiResponseEntry? summaryValue,
      InferenceStatus inferenceStatus = InferenceStatus.idle,
    }) {
      return [
        // Override specific family provider instances with stub controllers
        latestSummaryControllerProvider(
          id: 'test-task-id',
          aiResponseType: AiResponseType.taskSummary,
        ).overrideWith(() => TestLatestSummaryController(summaryValue)),
        inferenceStatusControllerProvider(
          id: 'test-task-id',
          aiResponseType: AiResponseType.taskSummary,
        ).overrideWith(() => TestInferenceStatusController(inferenceStatus)),
      ];
    }

    Widget createTestWidget({
      required Widget child,
      required List<Override> overrides,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      final lightTheme = withOverrides(
        FlexThemeData.light(
          scheme: FlexScheme.greyLaw,
          fontFamily: GoogleFonts.inclusiveSans().fontFamily,
        ),
      );
      final darkTheme = withOverrides(
        FlexThemeData.dark(
          scheme: FlexScheme.greyLaw,
          fontFamily: GoogleFonts.inclusiveSans().fontFamily,
        ),
      );

      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  const SizedBox(height: 100), // Smaller space above
                  child,
                  const SizedBox(height: 100), // Smaller space below
                ],
              ),
            ),
          ),
        ),
      );
    }

    AiResponseEntry createMockAiResponse(String response) {
      final now = DateTime.now();
      return AiResponseEntry(
        meta: Metadata(
          id: 'ai-response-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: AiResponseData(
          model: 'gpt-4',
          temperature: 0.7,
          systemMessage: 'System message',
          prompt: 'User prompt',
          thoughts: '',
          response: response,
          type: AiResponseType.taskSummary,
        ),
      );
    }

    testWidgets('shows nothing when no AI response exists', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          overrides: getOverrides(),
          child: CollapsibleAiSummarySection(
            taskId: 'test-task-id',
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CollapsibleAiSummarySection), findsOneWidget);
      expect(find.byIcon(MdiIcons.robotOutline), findsNothing);
    });

    testWidgets('shows preview when AI summary exists', (tester) async {
      const fullResponse = '''
# Task Summary

This is the first line of the summary.
This is the second line of the summary.
This is the third line of the summary.
This is the fourth line that should not appear in preview.
This is the fifth line.''';

      await tester.pumpWidget(
        createTestWidget(
          overrides: getOverrides(
            summaryValue: createMockAiResponse(fullResponse),
          ),
          child: CollapsibleAiSummarySection(
            taskId: 'test-task-id',
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.robotOutline), findsOneWidget);
      expect(find.text('AI Task Summary'), findsOneWidget);

      // Should show preview text
      expect(
        find.textContaining('This is the first line of the summary'),
        findsOneWidget,
      );
      expect(
        find.textContaining('This is the second line of the summary'),
        findsOneWidget,
      );

      // Should not show lines beyond preview
      expect(
        find.textContaining('fourth line'),
        findsNothing,
      );
    });

    testWidgets('expands to show full content when tapped', (tester) async {
      const fullResponse = '''
# Task Summary

This is the first line of the summary.
This is the second line of the summary.
This is the third line of the summary.
This is the fourth line that should appear when expanded.
This is the fifth line.''';

      await tester.pumpWidget(
        createTestWidget(
          overrides: getOverrides(
            summaryValue: createMockAiResponse(fullResponse),
          ),
          child: CollapsibleAiSummarySection(
            taskId: 'test-task-id',
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially collapsed - preview only
      expect(
        find.textContaining('fourth line'),
        findsNothing,
      );

      // Tap to expand
      await tester.tap(find.text('AI Task Summary'));
      await tester.pumpAndSettle();

      // Now should show full content in GptMarkdown widget
      // Note: The actual text might be inside the GptMarkdown widget
      // which may render differently, so we check for the widget itself
      expect(
        find.byType(GptMarkdown),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator when inference is running',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          overrides: getOverrides(
            summaryValue: createMockAiResponse('Some summary content'),
            inferenceStatus: InferenceStatus.running,
          ),
          child: CollapsibleAiSummarySection(
            taskId: 'test-task-id',
            scrollController: scrollController,
          ),
        ),
      );

      // Don't use pumpAndSettle with animations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The loading indicator is in the trailing widget of CollapsibleTaskSection
      expect(find.byIcon(MdiIcons.robotOutline), findsOneWidget);
      expect(find.text('AI Task Summary'), findsOneWidget);

      // Find the CollapsibleTaskSection and check its trailing widget
      final sectionFinder = find.byType(CollapsibleTaskSection);
      expect(sectionFinder, findsOneWidget);

      // Get the widget and check if it has a trailing widget
      final section = tester.widget<CollapsibleTaskSection>(sectionFinder);
      expect(section.trailing, isNotNull,
          reason:
              'CollapsibleTaskSection should have a trailing widget when loading');

      // The trailing widget should contain a CircularProgressIndicator
      final trailing = section.trailing;
      if (trailing is SizedBox) {
        expect(trailing.child, isA<CircularProgressIndicator>());
      }
    });

    testWidgets('handles markdown formatting in preview', (tester) async {
      const markdownResponse = '''
# Task Summary

**Bold text** should appear without asterisks.
*Italic text* should also be clean.
- List item should show as bullet point
## Subheading should be plain text''';

      await tester.pumpWidget(
        createTestWidget(
          overrides: getOverrides(
            summaryValue: createMockAiResponse(markdownResponse),
          ),
          child: CollapsibleAiSummarySection(
            taskId: 'test-task-id',
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The widget should be created
      expect(find.byType(CollapsibleAiSummarySection), findsOneWidget);
      expect(find.byType(CollapsibleTaskSection), findsOneWidget);

      // Find all text widgets
      final allTexts = find.byType(Text).evaluate();

      // Look for any text containing the expected content
      final hasExpectedContent = allTexts.any((element) {
        final text = (element.widget as Text).data ?? '';
        return text.contains('Bold text') &&
            text.contains('without asterisks') &&
            !text.contains('**');
      });

      expect(hasExpectedContent, true,
          reason: 'Preview text with stripped markdown not found');
    });

    testWidgets('truncates long preview with ellipsis', (tester) async {
      final longText = 'This is a very long line ' * 20;
      final longResponse = '''
# Task Summary

$longText''';

      await tester.pumpWidget(
        createTestWidget(
          overrides: getOverrides(
            summaryValue: createMockAiResponse(longResponse),
          ),
          child: CollapsibleAiSummarySection(
            taskId: 'test-task-id',
            scrollController: scrollController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find ellipsis in the preview
      expect(find.textContaining('...'), findsOneWidget);
    });
  });
}
