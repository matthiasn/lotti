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
      expect(
        tester.getSize(find.byKey(const Key('design-system-search-shell'))),
        const Size(244, 56),
      );
      expect(
        tester.getTopLeft(find.byIcon(Icons.search_rounded)).dx,
        closeTo(12, 0.1),
      );
      expect(
        tester.getTopLeft(find.text('Type user')).dx,
        closeTo(44, 0.1),
      );
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);

      final mediumEditableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      final mediumTextField = tester.widget<TextField>(find.byType(TextField));
      expect(mediumEditableText.style.height, 1);
      expect(mediumTextField.textAlignVertical, TextAlignVertical.center);
      expect(mediumTextField.decoration!.border, InputBorder.none);
      expect(mediumTextField.decoration!.enabledBorder, InputBorder.none);
      expect(mediumTextField.decoration!.disabledBorder, InputBorder.none);
      expect(mediumTextField.decoration!.focusedBorder, InputBorder.none);
      expect(mediumTextField.decoration!.errorBorder, InputBorder.none);
      expect(
        mediumTextField.decoration!.focusedErrorBorder,
        InputBorder.none,
      );
      expect(
        (tester.getCenter(find.text('Type user')).dy -
                tester
                    .getCenter(
                      find.byKey(const Key('design-system-search-shell')),
                    )
                    .dy)
            .abs(),
        lessThanOrEqualTo(4),
      );

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
      final textField = tester.widget<TextField>(find.byType(TextField));

      expect(
        editableText.style.fontSize,
        dsTokensLight.typography.size.bodySmall,
      );
      expect(editableText.style.height, 1);
      expect(
        tester.getSize(find.byKey(const Key('design-system-search-shell'))),
        const Size(244, 48),
      );
      expect(
        tester.getTopLeft(find.byIcon(Icons.search_rounded)).dx,
        closeTo(12, 0.1),
      );
      expect(
        tester.getTopLeft(find.text('Lotti search')).dx,
        closeTo(40, 0.1),
      );
      expect(textField.textAlignVertical, TextAlignVertical.center);
      expect(
        (tester.getCenter(find.text('Lotti search')).dy -
                tester
                    .getCenter(
                      find.byKey(const Key('design-system-search-shell')),
                    )
                    .dy)
            .abs(),
        lessThanOrEqualTo(4),
      );
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();

      expect(searched, 'Lotti search');
    });

    testWidgets('preserves typed text across external-state rebuilds', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 244,
            child: _SearchRebuildHarness(),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'a',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ab',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.controller.text, 'ab');
      expect(find.text('ab'), findsOneWidget);
    });

    testWidgets('grows beyond its minimum height at very large text scales', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 244,
            child: DesignSystemSearch(
              hintText: 'Type user',
              size: DesignSystemSearchSize.small,
              initialText: 'Scaled search',
            ),
          ),
          theme: DesignSystemTheme.light(),
          mediaQueryData: const MediaQueryData(
            size: Size(800, 600),
            textScaler: TextScaler.linear(4),
          ),
        ),
      );

      expect(
        tester
            .getSize(find.byKey(const Key('design-system-search-shell')))
            .height,
        greaterThan(48),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

class _SearchRebuildHarness extends StatefulWidget {
  const _SearchRebuildHarness();

  @override
  State<_SearchRebuildHarness> createState() => _SearchRebuildHarnessState();
}

class _SearchRebuildHarnessState extends State<_SearchRebuildHarness> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return DesignSystemSearch(
      hintText: 'Type user',
      initialText: query,
      onChanged: (value) {
        setState(() {
          query = value;
        });
      },
    );
  }
}
