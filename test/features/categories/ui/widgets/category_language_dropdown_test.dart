import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/ui/widgets/category_language_dropdown.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategoryLanguageDropdown', () {
    Future<void> pumpDropdown(
      WidgetTester tester, {
      String? languageCode,
      VoidCallback? onTap,
    }) {
      return tester.pumpWidget(
        WidgetTestBench(
          child: CategoryLanguageDropdown(
            languageCode: languageCode,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    testWidgets(
      'renders as a settings picker field without a duplicate label — the '
      'hosting section header already names it; semantics keep the name',
      (tester) async {
        await pumpDropdown(tester);

        final field = tester.widget<SettingsPickerField>(
          find.byType(SettingsPickerField),
        );
        expect(field.label, isNull);
        expect(field.semanticsLabel, 'Language');
        expect(field.hintText, 'Select Language');
        expect(find.text('Language'), findsNothing);
      },
    );

    testWidgets('shows the hint and no flag when no language is selected', (
      tester,
    ) async {
      await pumpDropdown(tester);

      expect(find.text('Select Language'), findsOneWidget);
      expect(find.byType(CountryFlag), findsNothing);
      // The kit field renders the dropdown chevron.
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('shows the language name and flag when selected', (
      tester,
    ) async {
      await pumpDropdown(tester, languageCode: 'en');

      expect(find.text('English'), findsOneWidget);
      expect(find.byType(CountryFlag), findsOneWidget);
      expect(find.text('Select Language'), findsNothing);
    });

    testWidgets('calls onTap when the field is tapped', (tester) async {
      var tapCount = 0;
      await pumpDropdown(tester, onTap: () => tapCount++);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('displays different languages correctly', (tester) async {
      const testCases = [
        ('es', 'Spanish'),
        ('fr', 'French'),
        ('de', 'German'),
        ('ja', 'Japanese'),
        ('zh', 'Chinese'),
      ];

      for (final (code, expectedName) in testCases) {
        await pumpDropdown(tester, languageCode: code);

        expect(find.text(expectedName), findsOneWidget);
        expect(find.byType(CountryFlag), findsOneWidget);
      }
    });

    testWidgets('falls back to the hint for unknown language codes', (
      tester,
    ) async {
      await pumpDropdown(tester, languageCode: 'invalid');

      // Unknown codes resolve to no language: hint shown, no flag, no crash.
      expect(find.text('Select Language'), findsOneWidget);
      expect(find.byType(CountryFlag), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('has no clear affordance — clearing happens in the modal', (
      tester,
    ) async {
      await pumpDropdown(tester, languageCode: 'en');

      final field = tester.widget<SettingsPickerField>(
        find.byType(SettingsPickerField),
      );
      expect(field.onClear, isNull);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });
}
