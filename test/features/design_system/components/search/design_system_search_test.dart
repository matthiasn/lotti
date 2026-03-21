import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemSearch', () {
    testWidgets('renders placeholder styles and clears entered text', (
      tester,
    ) async {
      var cleared = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 244,
            child: DesignSystemSearch(
              hintText: 'Type user',
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.text('Type user'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'Lotti search');
      await tester.pump();

      expect(find.text('Lotti search'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 244,
            child: DesignSystemSearch(
              hintText: 'Type user',
              onClear: () => cleared = true,
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Lotti search');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pump();

      expect(find.text('Lotti search'), findsNothing);
      expect(cleared, isTrue);
    });

    testWidgets('uses size-specific text styles and search callback', (
      tester,
    ) async {
      String? searched;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 244,
            child: DesignSystemSearch(
              hintText: 'Type user',
              size: DesignSystemSearchSize.small,
              initialText: 'Lotti search',
              onSearchPressed: (value) => searched = value,
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );

      expect(
        editableText.style.fontSize,
        dsTokensLight.typography.size.bodySmall,
      );

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();

      expect(searched, 'Lotti search');
    });
  });
}
