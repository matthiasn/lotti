import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_speech_dictionary.dart';

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

      // Verify label is shown
      expect(find.text('Speech Dictionary'), findsOneWidget);

      // Verify hint is shown (actual l10n string)
      expect(
        find.text('macOS; Kirkjubæjarklaustur; Claude Code'),
        findsOneWidget,
      );

      // Verify helper text is shown (actual l10n string)
      expect(
        find.text('Semicolon-separated terms for better speech recognition'),
        findsOneWidget,
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

    testWidgets('parses terms correctly with various whitespace',
        (tester) async {
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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

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

    testWidgets('has correct icon', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify spellcheck icon is shown
      expect(find.byIcon(Icons.spellcheck_outlined), findsOneWidget);
    });

    testWidgets('supports multiline input', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify text field supports multiple lines
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, equals(3));
      expect(textField.minLines, equals(1));
    });

    testWidgets('has word capitalization', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: null,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify text capitalization is words
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textCapitalization, equals(TextCapitalization.words));
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

    testWidgets('does not update when dictionary is same as current text',
        (tester) async {
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

    testWidgets('updates when dictionary item differs at index',
        (tester) async {
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
      await tester.pumpAndSettle();

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
      expect(kDictionaryWarningThreshold, equals(30));
    });
  });

  group('Large dictionary warning', () {
    testWidgets('shows warning when dictionary exceeds threshold',
        (tester) async {
      // Create a dictionary with more than 30 terms
      final largeDict = List.generate(35, (i) => 'term$i');

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: largeDict,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify warning message is shown (contains term count)
      expect(find.textContaining('35'), findsOneWidget);
    });

    testWidgets('shows normal helper text when below threshold',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySpeechDictionary(
            dictionary: const ['term1', 'term2'],
            onChanged: (_) {},
          ),
        ),
      );

      // Verify normal helper text is shown
      expect(
        find.text('Semicolon-separated terms for better speech recognition'),
        findsOneWidget,
      );
    });
  });
}
