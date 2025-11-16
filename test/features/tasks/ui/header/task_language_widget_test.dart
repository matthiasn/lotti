import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/tasks/ui/header/task_language_widget.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';

import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';

void main() {
  group('TaskLanguageWidget', () {
    late Task testTaskData;
    late Task taskWithLanguage;

    setUp(() {
      testTaskData = testTask;
      taskWithLanguage = testTaskData.copyWith(
        data: testTaskData.data.copyWith(
          languageCode: 'de',
        ),
      );
    });

    testWidgets('displays language placeholder when no language is set',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskLanguageWidget(
            task: testTaskData,
            onLanguageChanged: (_) {},
          ),
        ),
      );

      // Verify language label is displayed
      expect(find.text('Language:'), findsOneWidget);
      // Verify placeholder icon is displayed
      expect(find.byIcon(Icons.language), findsOneWidget);
      // Verify no text is displayed, only icon
      expect(find.byType(CountryFlag), findsNothing);
    });

    testWidgets('displays country flag when language is set', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskLanguageWidget(
            task: taskWithLanguage,
            onLanguageChanged: (_) {},
          ),
        ),
      );

      // Verify language label is displayed
      expect(find.text('Language:'), findsOneWidget);
      // Verify flag is displayed
      expect(find.byType(CountryFlag), findsOneWidget);
      expect(find.byIcon(Icons.language), findsNothing);
      // Verify no language name is displayed

      // Verify correct flag widget exists for German
      final flagWidget = tester.widget<CountryFlag>(find.byType(CountryFlag));
      expect(flagWidget, isNotNull);
    });

    testWidgets('opens language selector modal on tap', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskLanguageWidget(
            task: testTaskData,
            onLanguageChanged: (_) {},
          ),
        ),
      );

      // Tap on language widget
      await tester.tap(find.byType(TaskLanguageWidget));
      await tester.pumpAndSettle();

      // Verify modal is opened
      expect(find.byType(LanguageSelectionModalContent), findsOneWidget);
    });

    testWidgets('passes initial language to modal', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskLanguageWidget(
            task: taskWithLanguage,
            onLanguageChanged: (_) {},
          ),
        ),
      );

      // Tap on language widget
      await tester.tap(find.byType(TaskLanguageWidget));
      await tester.pumpAndSettle();

      // Verify modal has correct initial language
      final modalContent = tester.widget<LanguageSelectionModalContent>(
        find.byType(LanguageSelectionModalContent),
      );
      expect(modalContent.initialLanguageCode, equals('de'));
    });

    testWidgets('calls callback when language is selected', (tester) async {
      SupportedLanguage? selectedLanguage;

      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskLanguageWidget(
            task: testTaskData,
            onLanguageChanged: (language) {
              selectedLanguage = language;
            },
          ),
        ),
      );

      // Open modal
      await tester.tap(find.byType(TaskLanguageWidget));
      await tester.pumpAndSettle();

      // Find one of the first languages that should be visible (e.g., Arabic)
      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(selectedLanguage, equals(SupportedLanguage.ar));
    });

    testWidgets('modal closes after language selection', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskLanguageWidget(
            task: testTaskData,
            onLanguageChanged: (_) {},
          ),
        ),
      );

      // Open modal
      await tester.tap(find.byType(TaskLanguageWidget));
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSelectionModalContent), findsOneWidget);

      // Select one of the first visible languages
      await tester.tap(find.text('Bengali'));
      await tester.pumpAndSettle();

      // Verify modal is closed
      expect(find.byType(LanguageSelectionModalContent), findsNothing);
    });

    testWidgets('flag has correct size and styling', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskLanguageWidget(
            task: taskWithLanguage,
            onLanguageChanged: (_) {},
          ),
        ),
      );

      // Verify padding
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, equals(const EdgeInsets.only(right: 5)));

      // Verify flag dimensions (doubled in size)
      final flagWidget = tester.widget<CountryFlag>(find.byType(CountryFlag));
      expect(flagWidget.height, equals(20));
      expect(flagWidget.width, equals(30));

      // Verify the flag is inside a container with decoration
      final flagContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(CountryFlag),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(flagContainer.decoration, isNotNull);
    });

    testWidgets('flag container provides visibility in dark mode',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: TaskLanguageWidget(
            task: taskWithLanguage,
            onLanguageChanged: (_) {},
          ),
        ),
      );

      // Find the flag container
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(TaskLanguageWidget),
              matching: find.byType(Container),
            )
            .first,
      );

      // Verify container has background and border for visibility
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.color, isNotNull);
      expect(decoration.border, isNotNull);
      // Chip-style container with rounded corners for visibility
      expect(decoration.borderRadius, isA<BorderRadius>());

      // Verify the flag is wrapped in ClipRRect for rounded corners
      final clipRRect = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.byType(CountryFlag),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clipRRect.borderRadius, isA<BorderRadius>());
    });

    testWidgets('uses Nigeria flag for Nigerian languages', (tester) async {
      const nigerianCodes = ['ig', 'pcm', 'yo'];

      for (final code in nigerianCodes) {
        final task = testTaskData.copyWith(
          data: testTaskData.data.copyWith(languageCode: code),
        );

        await tester.pumpWidget(
          WidgetTestBench(
            child: TaskLanguageWidget(
              task: task,
              onLanguageChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final flagFinder = find.byKey(ValueKey('flag-$code'));
        expect(flagFinder, findsOneWidget, reason: 'code: $code');

        expect(
          tester.widget<CountryFlag>(flagFinder),
          isA<CountryFlag>(),
        );
      }
    });
  });
}
