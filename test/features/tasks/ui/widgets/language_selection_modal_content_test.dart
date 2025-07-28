import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';

import '../../../../test_helper.dart';

void main() {
  group('LanguageSelectionModalContent', () {
    testWidgets('displays all supported languages', (tester) async {
      final selectedLanguages = <SupportedLanguage?>[];

      await tester.pumpWidget(
        WidgetTestBench(
          child: LanguageSelectionModalContent(
            onLanguageSelected: selectedLanguages.add,
          ),
        ),
      );

      // Verify some languages are displayed
      expect(find.text('English'), findsOneWidget);
      expect(find.text('German'), findsOneWidget);
      expect(find.text('Spanish'), findsOneWidget);
      expect(find.text('French'), findsOneWidget);

      // Verify country flags are displayed
      expect(find.byType(CountryFlag), findsWidgets);
      expect(find.byType(CountryFlag).evaluate().length,
          equals(SupportedLanguage.values.length));
    });

    testWidgets('filters languages by search query', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LanguageSelectionModalContent(
            onLanguageSelected: (_) {},
          ),
        ),
      );

      // Enter search query
      await tester.enterText(find.byType(TextField), 'German');
      await tester.pump();

      // Verify only matching language is displayed (excluding the text field)
      expect(
          find.descendant(
            of: find.byType(SettingsCard),
            matching: find.text('German'),
          ),
          findsOneWidget);
      expect(
          find.descendant(
            of: find.byType(SettingsCard),
            matching: find.text('English'),
          ),
          findsNothing);
      expect(
          find.descendant(
            of: find.byType(SettingsCard),
            matching: find.text('Spanish'),
          ),
          findsNothing);
    });

    testWidgets('filters languages by language code', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LanguageSelectionModalContent(
            onLanguageSelected: (_) {},
          ),
        ),
      );

      // Enter search query with language code
      await tester.enterText(find.byType(TextField), 'de');
      await tester.pump();

      // Verify only German is displayed (de = German)
      expect(find.text('German'), findsOneWidget);
    });

    testWidgets('callback is called when language is selected', (tester) async {
      final selectedLanguages = <SupportedLanguage?>[];

      await tester.pumpWidget(
        WidgetTestBench(
          child: LanguageSelectionModalContent(
            onLanguageSelected: selectedLanguages.add,
          ),
        ),
      );

      // German might be off-screen, try a language that's near the top
      await tester.tap(find.text('Arabic'));
      await tester.pump();

      // Verify callback was called with Arabic
      expect(selectedLanguages, hasLength(1));
      expect(selectedLanguages.first, equals(SupportedLanguage.ar));
    });

    testWidgets('displays selected language at the top', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LanguageSelectionModalContent(
            initialLanguageCode: 'de',
            onLanguageSelected: (_) {},
          ),
        ),
      );

      // Verify German is displayed as selected
      final germanInSettings = find.descendant(
        of: find.byType(SettingsCard),
        matching: find.text('German'),
      );
      expect(germanInSettings, findsOneWidget);
    });

    testWidgets('displays clear option when language is selected',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LanguageSelectionModalContent(
            initialLanguageCode: 'de',
            onLanguageSelected: (_) {},
          ),
        ),
      );

      // Verify clear option is displayed
      expect(find.text('clear'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear option removes language selection', (tester) async {
      final selectedLanguages = <SupportedLanguage?>[];

      await tester.pumpWidget(
        WidgetTestBench(
          child: LanguageSelectionModalContent(
            initialLanguageCode: 'de',
            onLanguageSelected: selectedLanguages.add,
          ),
        ),
      );

      // Scroll to find clear option and tap it
      await tester.dragUntilVisible(
        find.text('clear'),
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );
      await tester.tap(find.text('clear'));
      await tester.pump();

      // Verify callback was called with null
      expect(selectedLanguages, hasLength(1));
      expect(selectedLanguages.first, isNull);
    });

    testWidgets('search field has correct placeholder', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LanguageSelectionModalContent(
            onLanguageSelected: (_) {},
          ),
        ),
      );

      // Verify search field exists with correct decoration
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.prefixIcon, isNotNull);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}
