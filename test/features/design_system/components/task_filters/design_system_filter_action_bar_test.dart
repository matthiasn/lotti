import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

const ValueKey<String> _clearKey = ValueKey('filter-bar-clear');
const ValueKey<String> _applyKey = ValueKey('filter-bar-apply');
const ValueKey<String> _saveKey = ValueKey('filter-bar-save');

Future<void> _pumpBar(
  WidgetTester tester, {
  VoidCallback? onClear,
  VoidCallback? onApply,
  List<Widget> extraSecondary = const [],
}) async {
  await tester.pumpWidget(
    makeTestableWidget(
      Material(
        child: DesignSystemFilterActionBar(
          clearKey: _clearKey,
          applyKey: _applyKey,
          clearLabel: 'Clear',
          applyLabel: 'Apply',
          onClearPressed: onClear,
          onApplyPressed: onApply,
          extraSecondary: extraSecondary,
        ),
      ),
    ),
  );
  await tester.pump();
}

DesignSystemButton _button(WidgetTester tester, Key key) =>
    tester.widget<DesignSystemButton>(find.byKey(key));

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  group('actions', () {
    testWidgets('labels both actions and puts the confirm glyph on Apply', (
      tester,
    ) async {
      await _pumpBar(tester, onClear: () {}, onApply: () {});

      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_applyKey),
          matching: find.byIcon(LottiIcons.confirm),
        ),
        findsOneWidget,
      );
      expect(_button(tester, _clearKey).leadingIcon, isNull);
      expect(
        _button(tester, _clearKey).variant,
        DesignSystemButtonVariant.secondary,
      );
      expect(
        _button(tester, _applyKey).variant,
        DesignSystemButtonVariant.primary,
      );
    });

    testWidgets('Apply reports exactly one press per tap', (tester) async {
      var applyCalls = 0;
      var clearCalls = 0;
      await _pumpBar(
        tester,
        onClear: () => clearCalls++,
        onApply: () => applyCalls++,
      );

      await tester.tap(find.byKey(_applyKey));
      await tester.pump();

      expect(applyCalls, 1);
      expect(clearCalls, 0);
    });

    testWidgets('Clear reports exactly one press per tap', (tester) async {
      var applyCalls = 0;
      var clearCalls = 0;
      await _pumpBar(
        tester,
        onClear: () => clearCalls++,
        onApply: () => applyCalls++,
      );

      await tester.tap(find.byKey(_clearKey));
      await tester.pump();

      expect(clearCalls, 1);
      expect(applyCalls, 0);
    });

    testWidgets('a null Clear handler keeps the button visible but inert', (
      tester,
    ) async {
      await _pumpBar(tester, onApply: () {});

      expect(find.text('Clear'), findsOneWidget);
      expect(_button(tester, _clearKey).onPressed, isNull);
      expect(_button(tester, _applyKey).onPressed, isNotNull);
    });

    testWidgets('a null Apply handler keeps the button visible but inert', (
      tester,
    ) async {
      await _pumpBar(tester, onClear: () {});

      expect(find.text('Apply'), findsOneWidget);
      expect(_button(tester, _applyKey).onPressed, isNull);
      expect(_button(tester, _clearKey).onPressed, isNotNull);
    });

    testWidgets('extra secondaries sit between Clear and Apply', (
      tester,
    ) async {
      await _pumpBar(
        tester,
        onClear: () {},
        onApply: () {},
        extraSecondary: [
          DesignSystemButton(
            key: _saveKey,
            label: 'Save',
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.large,
            onPressed: () {},
          ),
        ],
      );

      final clearLeft = tester.getTopLeft(find.byKey(_clearKey)).dx;
      final saveLeft = tester.getTopLeft(find.byKey(_saveKey)).dx;
      final applyLeft = tester.getTopLeft(find.byKey(_applyKey)).dx;
      expect(clearLeft, lessThan(saveLeft));
      expect(saveLeft, lessThan(applyLeft));
    });
  });

  group('stickyClearance', () {
    const phoneWidth = WoltModalConfig.pageBreakpoint - 1.0;
    const dialogWidth = WoltModalConfig.pageBreakpoint + 1.0;
    const largeText = TextScales.large + 0.1;

    Future<(double clearance, DsSpacing spacing)> measure(
      WidgetTester tester, {
      required double width,
      required double textScale,
    }) async {
      late double clearance;
      late DsSpacing spacing;
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              clearance = DesignSystemFilterActionBar.stickyClearance(context);
              spacing = context.designTokens.spacing;
              return const SizedBox.shrink();
            },
          ),
          mediaQueryData: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(textScale),
          ),
        ),
      );
      await tester.pump();
      return (clearance, spacing);
    }

    testWidgets('a bottom sheet reserves the full bar height', (tester) async {
      final (clearance, spacing) = await measure(
        tester,
        width: phoneWidth,
        textScale: 1,
      );
      expect(clearance, spacing.step13);
    });

    testWidgets('a bottom sheet at large text reserves the stacked bar', (
      tester,
    ) async {
      final (clearance, spacing) = await measure(
        tester,
        width: phoneWidth,
        textScale: largeText,
      );
      expect(clearance, spacing.step13 + spacing.step12);
    });

    testWidgets('a dialog reserves less because its page grows', (
      tester,
    ) async {
      final (clearance, spacing) = await measure(
        tester,
        width: dialogWidth,
        textScale: 1,
      );
      expect(clearance, spacing.step12);
    });

    testWidgets('a dialog ignores large text', (tester) async {
      final (clearance, spacing) = await measure(
        tester,
        width: dialogWidth,
        textScale: largeText,
      );
      expect(clearance, spacing.step12);
    });
  });
}
