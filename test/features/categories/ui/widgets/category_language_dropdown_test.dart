import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_language_dropdown.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategoryLanguageDropdown', () {
    testWidgets('displays correctly with no language selected', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: null,
            onTap: () => tapCount++,
          ),
        ),
      );

      // Verify label text (note capital L)
      expect(find.text('Default Language'), findsOneWidget);
      expect(find.text('No default language'), findsOneWidget);

      // Verify icon
      expect(find.byIcon(Icons.translate), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      // Verify no flag is shown
      expect(find.byType(CountryFlag), findsNothing);
    });

    testWidgets('displays correctly with language selected', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: 'en',
            onTap: () {},
          ),
        ),
      );

      // Verify language name is displayed
      expect(find.text('English'), findsOneWidget);

      // Verify flag is shown
      expect(find.byType(CountryFlag), findsOneWidget);

      // Verify hint text is not shown
      expect(find.text('No default language'), findsNothing);
    });

    testWidgets('calls onTap when pressed', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: null,
            onTap: () => tapCount++,
          ),
        ),
      );

      // Tap the dropdown
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('displays different languages correctly', (tester) async {
      final testCases = [
        ('es', 'Spanish'),
        ('fr', 'French'),
        ('de', 'German'),
        ('ja', 'Japanese'),
        ('zh', 'Chinese'),
      ];

      for (final (code, expectedName) in testCases) {
        await tester.pumpWidget(
          WidgetTestBench(
            child: CategoryLanguageDropdown(
              languageCode: code,
              onTap: () {},
            ),
          ),
        );

        expect(find.text(expectedName), findsOneWidget);
        expect(find.byType(CountryFlag), findsOneWidget);

        // Just verify the flag is present - we can't check its language code directly
      }
    });

    testWidgets('has correct visual structure', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: 'fr',
            onTap: () {},
          ),
        ),
      );

      // Verify structure
      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byType(InputDecorator), findsOneWidget);
      expect(find.byType(Row), findsWidgets);

      // Verify flag dimensions
      final flag = tester.widget<CountryFlag>(find.byType(CountryFlag));
      expect(flag.height, 20);
      expect(flag.width, 30);

      // Verify spacing - find SizedBox with width 8
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(Row),
          matching: find.byType(SizedBox),
        ),
      );
      final spacingSizedBox = sizedBoxes.firstWhere(
        (box) => box.width == 8,
        orElse: () => throw Exception('No SizedBox with width 8 found'),
      );
      expect(spacingSizedBox.width, 8);
    });

    testWidgets('responds to theme changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: WidgetTestBench(
            child: CategoryLanguageDropdown(
              languageCode: null,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify it renders correctly in dark theme
      expect(find.byType(CategoryLanguageDropdown), findsOneWidget);

      // Get the hint text and verify it uses hint color
      final noDefaultText = find.text('No default language');
      expect(noDefaultText, findsOneWidget);

      final text = tester.widget<Text>(noDefaultText);
      final context = tester.element(noDefaultText);
      expect(text.style?.color, Theme.of(context).hintColor);
    });

    testWidgets('handles invalid language codes gracefully', (tester) async {
      // This should not crash even with invalid code
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: 'invalid',
            onTap: () {},
          ),
        ),
      );

      // Should still render without errors
      expect(find.byType(CategoryLanguageDropdown), findsOneWidget);
    });

    testWidgets('has correct InputDecorator properties', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: 'ja',
            onTap: () {},
          ),
        ),
      );

      final inputDecorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );

      expect(inputDecorator.decoration.labelText, 'Default Language');
      expect(inputDecorator.decoration.hintText, 'Select Language');

      final border = inputDecorator.decoration.border! as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('InkWell has correct border radius', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: null,
            onTap: () {},
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('text uses correct style from theme', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: 'en',
            onTap: () {},
          ),
        ),
      );

      final englishText = find.text('English');
      expect(englishText, findsOneWidget);

      final text = tester.widget<Text>(englishText);
      final context = tester.element(englishText);
      expect(text.style, Theme.of(context).textTheme.bodyLarge);
    });

    testWidgets('multiple rapid taps are handled correctly', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: 'es',
            onTap: () => tapCount++,
          ),
        ),
      );

      // Rapidly tap multiple times
      await tester.tap(find.byType(InkWell));
      await tester.tap(find.byType(InkWell));
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapCount, 3);
    });
  });
}
