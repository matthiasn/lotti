import 'dart:ui' show BoxHeightStyle, TextLeadingDistribution;

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

      final visibleHintFinder = _visibleText('Type user');

      expect(visibleHintFinder, findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('design-system-search-shell'))),
        const Size(244, 56),
      );
      expect(
        tester.getTopLeft(find.byIcon(Icons.search_rounded)).dx,
        closeTo(12, 0.1),
      );
      expect(
        tester.getTopLeft(visibleHintFinder).dx,
        closeTo(44, 0.1),
      );
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);

      final mediumEditableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      final mediumTextField = tester.widget<TextField>(find.byType(TextField));
      expect(mediumTextField.decoration!.hintText, 'Type user');
      expect(
        mediumEditableText.style.height,
        dsTokensLight.typography.styles.body.bodyMedium.height,
      );
      expect(
        mediumEditableText.style.leadingDistribution,
        TextLeadingDistribution.even,
      );
      expect(
        mediumTextField.textAlignVertical,
        const TextAlignVertical(y: -0.3),
      );
      expect(
        mediumTextField.cursorHeight,
        dsTokensLight.typography.styles.body.bodyMedium.fontSize! *
            dsTokensLight.typography.styles.body.bodyMedium.height!,
      );
      expect(
        mediumTextField.selectionHeightStyle,
        BoxHeightStyle.tight,
      );
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
        (tester.getCenter(visibleHintFinder).dy -
                tester
                    .getCenter(
                      find.byKey(const Key('design-system-search-shell')),
                    )
                    .dy)
            .abs(),
        lessThanOrEqualTo(2),
      );

      final placeholderCenter = tester.getCenter(visibleHintFinder).dy;
      final placeholderTop = tester.getTopLeft(visibleHintFinder).dy;
      final iconCenter = tester.getCenter(find.byIcon(Icons.search_rounded)).dy;
      expect((placeholderCenter - iconCenter).abs(), lessThanOrEqualTo(1.5));

      await tester.enterText(find.byType(TextField), 'Lotti search');
      await tester.pump();

      expect(find.text('Lotti search'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(
        (tester.getCenter(find.text('Lotti search')).dy - iconCenter).abs(),
        lessThanOrEqualTo(1.5),
      );
      expect(
        (tester.getTopLeft(find.text('Lotti search')).dy - placeholderTop)
            .abs(),
        lessThanOrEqualTo(1),
      );

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
      expect(
        editableText.style.height,
        dsTokensLight.typography.styles.body.bodySmall.height,
      );
      expect(
        editableText.style.leadingDistribution,
        TextLeadingDistribution.even,
      );
      expect(
        textField.cursorHeight,
        dsTokensLight.typography.styles.body.bodySmall.fontSize! *
            dsTokensLight.typography.styles.body.bodySmall.height!,
      );
      expect(
        textField.selectionHeightStyle,
        BoxHeightStyle.tight,
      );
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
      expect(
        textField.textAlignVertical,
        const TextAlignVertical(y: -0.3),
      );
      expect(
        (tester.getCenter(find.text('Lotti search')).dy -
                tester
                    .getCenter(
                      find.byKey(const Key('design-system-search-shell')),
                    )
                    .dy)
            .abs(),
        lessThanOrEqualTo(2),
      );
      expect(
        (tester.getCenter(find.text('Lotti search')).dy -
                tester.getCenter(find.byIcon(Icons.search_rounded)).dy)
            .abs(),
        lessThanOrEqualTo(1.5),
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

    testWidgets('grows beyond its minimum height at larger text scales', (
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
            textScaler: TextScaler.linear(2),
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

    testWidgets(
      'scales line height from scaled font size for non-linear text scaling',
      (
        tester,
      ) async {
        final fontSize =
            dsTokensLight.typography.styles.body.bodySmall.fontSize!;
        final lineHeight =
            fontSize * dsTokensLight.typography.styles.body.bodySmall.height!;
        final lineHeightMultiplier = lineHeight / fontSize;
        final expectedHeight =
            (const _ShiftTextScaler(10).scale(fontSize) *
                lineHeightMultiplier) +
            28;

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
              textScaler: _ShiftTextScaler(10),
            ),
          ),
        );

        expect(
          tester
              .getSize(find.byKey(const Key('design-system-search-shell')))
              .height,
          closeTo(expectedHeight, 0.01),
        );
      },
    );
  });
}

class _ShiftTextScaler extends TextScaler {
  const _ShiftTextScaler(this.delta);

  final double delta;

  @override
  double get textScaleFactor => 1;

  @override
  double scale(double fontSize) => fontSize + delta;

  @override
  bool operator ==(Object other) =>
      other is _ShiftTextScaler && other.delta == delta;

  @override
  int get hashCode => delta.hashCode;
}

Finder _visibleText(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data == text &&
        widget.style?.color != Colors.transparent,
    description: 'visible text "$text"',
  );
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
