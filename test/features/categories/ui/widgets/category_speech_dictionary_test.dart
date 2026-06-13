import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_speech_dictionary.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategorySpeechDictionary', () {
    testWidgets('displays correctly with empty dictionary', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (_) {},
          ),
        ),
      );

      // Renders as the design-system textarea; the hosting section
      // header names the field, so no visible in-field label — the name
      // lives in semantics.
      expect(find.byType(DesignSystemTextarea), findsOneWidget);
      expect(find.text('Speech Dictionary'), findsNothing);
      expect(
        tester
            .widget<DesignSystemTextarea>(find.byType(DesignSystemTextarea))
            .semanticsLabel,
        'Speech Dictionary',
      );
      expect(
        find.text('macOS; Kirkjubæjarklaustur; Claude Code'),
        findsOneWidget,
      );

      // The formatting explanation lives in the page's section description
      // now — the in-field helper slot stays empty below the warning
      // threshold (the textarea clips helpers to one line).
      expect(
        find.text(
          'Semicolon-separated terms (max 50 chars) for better speech recognition',
        ),
        findsNothing,
      );

      // Verify text field is empty
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('displays correctly with existing dictionary', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['macOS', 'iPhone', 'Anthropic'],
            onChanged: (_) {},
          ),
        ),
      );

      // Verify existing terms are displayed
      expect(find.text('macOS; iPhone; Anthropic'), findsOneWidget);
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      List<String>? changedTerms;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (terms) {
              changedTerms = terms;
            },
          ),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'term1; term2');
      await tester.pumpAndSettle();

      // Verify onChanged was called with parsed terms
      expect(changedTerms, equals(['term1', 'term2']));
    });

    testWidgets('parses terms correctly with various whitespace', (
      tester,
    ) async {
      List<String>? changedTerms;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (terms) {
              changedTerms = terms;
            },
          ),
        ),
      );

      // Enter text with various whitespace
      await tester.enterText(
        find.byType(TextField),
        '  term1  ;  term2  ;  term3  ',
      );
      await tester.pumpAndSettle();

      // Verify terms are trimmed
      expect(changedTerms, equals(['term1', 'term2', 'term3']));
    });

    testWidgets('filters out empty terms', (tester) async {
      List<String>? changedTerms;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (terms) {
              changedTerms = terms;
            },
          ),
        ),
      );

      // Enter text with empty segments
      await tester.enterText(find.byType(TextField), 'term1;;term2;  ;term3');
      await tester.pumpAndSettle();

      // Verify empty terms are filtered out
      expect(changedTerms, equals(['term1', 'term2', 'term3']));
    });

    testWidgets('truncates terms exceeding max length', (tester) async {
      List<String>? changedTerms;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (terms) {
              changedTerms = terms;
            },
          ),
        ),
      );

      // Enter a term that exceeds 50 characters
      final longTerm = 'a' * 60; // 60 characters
      await tester.enterText(find.byType(TextField), longTerm);
      await tester.pump();

      // Verify term is truncated to 50 characters
      expect(changedTerms, hasLength(1));
      expect(changedTerms!.first.length, equals(kMaxTermLength));
      expect(changedTerms!.first, equals('a' * 50));
    });

    testWidgets('returns empty list for empty input', (tester) async {
      List<String>? changedTerms;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['initial'],
            onChanged: (terms) {
              changedTerms = terms;
            },
          ),
        ),
      );

      // Clear the text field
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // Verify empty list is returned
      expect(changedTerms, isEmpty);
    });

    testWidgets('returns empty list for whitespace-only input', (tester) async {
      List<String>? changedTerms;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['initial'],
            onChanged: (terms) {
              changedTerms = terms;
            },
          ),
        ),
      );

      // Enter only whitespace
      await tester.enterText(find.byType(TextField), '   ;   ;   ');
      await tester.pumpAndSettle();

      // Verify empty list is returned
      expect(changedTerms, isEmpty);
    });

    testWidgets('renders no in-field glyph — the section header carries it', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (_) {},
          ),
        ),
      );

      // The page section header shows the spellcheck icon; duplicating it
      // inside the field would be noise.
      expect(find.byIcon(Icons.spellcheck_outlined), findsNothing);
    });

    testWidgets('supports multiline input via the textarea defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (_) {},
          ),
        ),
      );

      // DesignSystemTextarea defaults: minLines 3, maxLines minLines + 2.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, equals(3));
      expect(textField.maxLines, equals(5));
    });

    testWidgets('updates when dictionary changes externally', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['initial'],
            onChanged: (_) {},
          ),
        ),
      );

      // Verify initial value
      expect(find.text('initial'), findsOneWidget);

      // Rebuild with new dictionary
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['updated', 'terms'],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify updated value is shown
      expect(find.text('updated; terms'), findsOneWidget);
    });

    testWidgets('does not update when dictionary is same as current text', (
      tester,
    ) async {
      // This tests the _listsEqual logic - when user has typed same terms,
      // didUpdateWidget should not clobber the text field
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['term1', 'term2'],
            onChanged: (_) {},
          ),
        ),
      );

      // Verify initial value
      expect(find.text('term1; term2'), findsOneWidget);

      // Rebuild with same dictionary (simulates external update with same data)
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['term1', 'term2'],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Text should remain unchanged
      expect(find.text('term1; term2'), findsOneWidget);
    });

    testWidgets('updates when dictionary lengths differ', (tester) async {
      // Tests _listsEqual early return when lengths differ
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['term1'],
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('term1'), findsOneWidget);

      // Rebuild with more terms
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['term1', 'term2', 'term3'],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('term1; term2; term3'), findsOneWidget);
    });

    testWidgets('updates when dictionary item differs at index', (
      tester,
    ) async {
      // Tests _listsEqual loop finding difference
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['term1', 'term2'],
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('term1; term2'), findsOneWidget);

      // Rebuild with same length but different item at index 1
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['term1', 'differentTerm'],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('term1; differentTerm'), findsOneWidget);
    });

    testWidgets('preserves single term formatting', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['OnlyOneTerm'],
            onChanged: (_) {},
          ),
        ),
      );

      // Single term should be displayed without separators
      expect(find.text('OnlyOneTerm'), findsOneWidget);
    });

    testWidgets('handles special characters in terms', (tester) async {
      List<String>? changedTerms;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (terms) {
              changedTerms = terms;
            },
          ),
        ),
      );

      // Enter terms with special characters
      await tester.enterText(
        find.byType(TextField),
        'C++; C#; Objective-C',
      );
      await tester.pumpAndSettle();

      // Verify special characters are preserved
      expect(changedTerms, equals(['C++', 'C#', 'Objective-C']));
    });

    testWidgets('handles Unicode characters', (tester) async {
      List<String>? changedTerms;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (terms) {
              changedTerms = terms;
            },
          ),
        ),
      );

      // Enter terms with Unicode characters
      await tester.enterText(
        find.byType(TextField),
        'Kirkjubæjarklaustur',
      );
      await tester.pump();

      // Verify Unicode characters are preserved
      expect(changedTerms, equals(['Kirkjubæjarklaustur']));
    });
  });

  group('kMaxTermLength constant', () {
    test('has correct value', () {
      expect(kMaxTermLength, equals(50));
    });
  });

  group('kDictionaryWarningThreshold constant', () {
    test('has correct value', () {
      // Raised from 30 to 500 to align with correction examples limit
      expect(kDictionaryWarningThreshold, equals(500));
    });
  });

  group('Large dictionary warning', () {
    testWidgets('shows warning when dictionary exceeds threshold', (
      tester,
    ) async {
      // Create a dictionary with more than 500 terms
      final largeDict = List.generate(505, (i) => 'term$i');

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: largeDict,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify warning message is shown (contains term count)
      expect(find.textContaining('505'), findsOneWidget);
    });

    testWidgets('shows no helper text when below threshold', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['term1', 'term2'],
            onChanged: (_) {},
          ),
        ),
      );

      // Below the threshold the helper slot stays empty — the section
      // description on the page explains the format instead.
      final textarea = tester.widget<DesignSystemTextarea>(
        find.byType(DesignSystemTextarea),
      );
      expect(textarea.helperText, isNull);
    });
  });
}
