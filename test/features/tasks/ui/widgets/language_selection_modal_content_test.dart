import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';

import '../../../../test_helper.dart';

void main() {
  group('LanguageSelectionModalContent', () {
    Future<void> pumpModal(
      WidgetTester tester, {
      LanguageCallback? onLanguageSelected,
      String? initialLanguageCode,
    }) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: SingleChildScrollView(
            child: LanguageSelectionModalContent(
              initialLanguageCode: initialLanguageCode,
              onLanguageSelected: onLanguageSelected ?? (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('displays all supported languages', (tester) async {
      final selectedLanguages = <SupportedLanguage?>[];

      await pumpModal(
        tester,
        onLanguageSelected: selectedLanguages.add,
      );

      expect(find.text('English'), findsOneWidget);
      expect(find.text('German'), findsOneWidget);
      expect(find.text('Spanish'), findsOneWidget);
      expect(find.text('French'), findsOneWidget);

      expect(find.byType(CountryFlag), findsWidgets);
      expect(find.byType(CountryFlag).evaluate().length,
          equals(SupportedLanguage.values.length));
    });

    testWidgets('filters languages by search query', (tester) async {
      await pumpModal(tester);

      await tester.enterText(find.byType(TextField), 'German');
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SettingsCard),
          matching: find.text('German'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SettingsCard),
          matching: find.text('English'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(SettingsCard),
          matching: find.text('Spanish'),
        ),
        findsNothing,
      );
    });

    testWidgets('filters languages by language code', (tester) async {
      await pumpModal(tester);

      await tester.enterText(find.byType(TextField), 'de');
      await tester.pump();

      expect(find.text('German'), findsOneWidget);
    });

    testWidgets('callback is called when language is selected', (tester) async {
      final selectedLanguages = <SupportedLanguage?>[];

      await pumpModal(
        tester,
        onLanguageSelected: selectedLanguages.add,
      );

      await tester.tap(find.text('Arabic'));
      await tester.pump();

      expect(selectedLanguages, hasLength(1));
      expect(selectedLanguages.first, equals(SupportedLanguage.ar));
    });

    testWidgets('displays selected language at the top', (tester) async {
      await pumpModal(
        tester,
        initialLanguageCode: 'de',
      );

      final germanInSettings = find.descendant(
        of: find.byType(SettingsCard),
        matching: find.text('German'),
      );
      expect(germanInSettings, findsOneWidget);
    });

    testWidgets('displays clear option when language is selected',
        (tester) async {
      await pumpModal(
        tester,
        initialLanguageCode: 'de',
      );

      expect(find.text('Clear'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear option removes language selection', (tester) async {
      final selectedLanguages = <SupportedLanguage?>[];

      await pumpModal(
        tester,
        initialLanguageCode: 'de',
        onLanguageSelected: selectedLanguages.add,
      );

      await tester.dragUntilVisible(
        find.text('Clear'),
        find.byType(SingleChildScrollView),
        const Offset(0, -80),
      );
      await tester.tap(find.text('Clear'));
      await tester.pump();

      expect(selectedLanguages, hasLength(1));
      expect(selectedLanguages.first, isNull);
    });

    testWidgets('search field has correct placeholder', (tester) async {
      await pumpModal(tester);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.prefixIcon, isNotNull);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('lists languages alphabetically by display name',
        (tester) async {
      await pumpModal(tester);

      final cards =
          tester.widgetList<SettingsCard>(find.byType(SettingsCard)).toList();

      final titles = cards.map((card) => card.title).toList();
      final sorted = List.of(titles)
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      expect(titles, equals(sorted));
    });

    testWidgets('shows Nigeria flag for Nigerian language codes',
        (tester) async {
      await pumpModal(tester);

      for (final code in ['ig', 'pcm', 'yo']) {
        expect(find.byKey(ValueKey('flag-$code')), findsOneWidget);
      }
    });
  });
}
