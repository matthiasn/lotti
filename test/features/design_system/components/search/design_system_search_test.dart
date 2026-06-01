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
      'swapping from an external controller to internal rewires listeners',
      (tester) async {
        final externalController = TextEditingController(
          text: 'external value',
        );
        addTearDown(externalController.dispose);

        await tester.pumpWidget(
          _swapHarness(controller: externalController),
        );

        // External controller drives the field and its non-empty text shows
        // the clear button.
        expect(find.text('external value'), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

        // Rebuild with no controller -> falls back to a fresh internal
        // controller (lines 71-72), which is empty.
        await tester.pumpWidget(_swapHarness());
        await tester.pump();

        expect(find.text('external value'), findsNothing);
        expect(find.byIcon(Icons.cancel_rounded), findsNothing);

        // Mutating the now-detached external controller must NOT rebuild the
        // widget (its listener was removed on line 69).
        externalController.text = 'detached';
        await tester.pump();
        expect(find.text('detached'), findsNothing);

        // The freshly created internal controller is wired up: typing rebuilds
        // and surfaces the clear button (listener re-added on line 77).
        await tester.enterText(find.byType(TextField), 'typed internally');
        await tester.pump();
        expect(find.text('typed internally'), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'swapping from internal to an external controller disposes the internal',
      (tester) async {
        // Start with no controller so an internal one is created lazily and
        // its text is observed.
        await tester.pumpWidget(_swapHarness(initialText: 'internal value'));
        expect(find.text('internal value'), findsOneWidget);

        final externalController = TextEditingController(text: 'now external');
        addTearDown(externalController.dispose);

        // Rebuild with an external controller -> internal is nulled out and
        // disposed (lines 74-75). No exception means the dispose path ran
        // cleanly and the old internal controller is no longer referenced.
        await tester.pumpWidget(_swapHarness(controller: externalController));
        await tester.pump();

        expect(find.text('internal value'), findsNothing);
        expect(find.text('now external'), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);

        // The external controller's listener was re-added (line 77): clearing
        // it rebuilds and hides the clear button.
        externalController.clear();
        await tester.pump();
        expect(find.text('now external'), findsNothing);
        expect(find.byIcon(Icons.cancel_rounded), findsNothing);
      },
    );

    testWidgets(
      'swapping between two external controllers keeps the field in sync',
      (tester) async {
        final controllerA = TextEditingController(text: 'value A');
        final controllerB = TextEditingController(text: 'value B');
        addTearDown(controllerA.dispose);
        addTearDown(controllerB.dispose);

        await tester.pumpWidget(_swapHarness(controller: controllerA));
        expect(find.text('value A'), findsOneWidget);

        // Swap to a different external controller. There is no internal
        // controller to dispose, so the else-branch (lines 74-77) runs without
        // disposing anything and re-wires the listener to controller B.
        await tester.pumpWidget(_swapHarness(controller: controllerB));
        await tester.pump();

        expect(find.text('value A'), findsNothing);
        expect(find.text('value B'), findsOneWidget);

        // controllerA is detached: mutating it does not rebuild the field.
        controllerA.text = 'changed A';
        await tester.pump();
        expect(find.text('changed A'), findsNothing);

        // controllerB is wired: mutating it rebuilds the field.
        controllerB.text = 'changed B';
        await tester.pump();
        expect(find.text('changed B'), findsOneWidget);
      },
    );

    testWidgets(
      'changing initialText with no controller syncs the internal controller',
      (tester) async {
        // Create the internal controller lazily by rendering once.
        await tester.pumpWidget(_swapHarness(initialText: 'first'));
        expect(find.text('first'), findsOneWidget);

        // Changing initialText to a different value drives
        // _syncInternalControllerText, which rewrites the controller value
        // (lines 230-234) and collapses the selection to the end.
        await tester.pumpWidget(_swapHarness(initialText: 'second'));
        await tester.pump();

        final editableText = tester.widget<EditableText>(
          find.byType(EditableText),
        );
        expect(editableText.controller.text, 'second');
        expect(
          editableText.controller.selection,
          const TextSelection.collapsed(offset: 6),
        );
        expect(find.text('second'), findsOneWidget);

        // Re-pumping with the SAME initialText hits the early-return guard
        // (text already equals nextText) and leaves the field unchanged.
        await tester.pumpWidget(_swapHarness(initialText: 'second'));
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'second',
        );
      },
    );

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

Widget _swapHarness({
  TextEditingController? controller,
  String? initialText,
}) {
  return makeTestableWidgetWithScaffold(
    SizedBox(
      width: 244,
      child: DesignSystemSearch(
        hintText: 'Type user',
        controller: controller,
        initialText: initialText,
      ),
    ),
    theme: DesignSystemTheme.light(),
  );
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
