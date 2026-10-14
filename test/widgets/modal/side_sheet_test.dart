import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/modal/side_sheet.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../../widget_test_utils.dart';

void main() {
  const wide = Size(1400, 900);
  const phone = Size(WoltModalConfig.pageBreakpoint - 1, 800);

  /// Resolves [sideSheetModalType] inside a tree of [size].
  Future<WoltModalType> typeAt(
    WidgetTester tester,
    Size size, {
    SizedWoltSideSheetType sideSheet = const SizedWoltSideSheetType(),
    bool fullHeightOnPhone = false,
  }) async {
    late WoltModalType type;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (context) {
            type = sideSheetModalType(
              context,
              sideSheet: sideSheet,
              fullHeightOnPhone: fullHeightOnPhone,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return type;
  }

  group('sideSheetModalType', () {
    testWidgets('a wide window gets the side sheet it was given', (
      tester,
    ) async {
      const panel = SizedWoltSideSheetType(
        widthFraction: 1,
        minWidth: 400,
        maxWidth: 400,
      );
      expect(await typeAt(tester, wide, sideSheet: panel), same(panel));
    });

    testWidgets('a phone gets a shrink-wrapping bottom sheet by default', (
      tester,
    ) async {
      final type = await typeAt(tester, phone);
      expect(type, isA<WoltBottomSheetType>());
      expect(type.forceMaxHeight, isFalse);
    });

    testWidgets('a phone gets a full-height bottom sheet when asked', (
      tester,
    ) async {
      final type = await typeAt(tester, phone, fullHeightOnPhone: true);
      expect(type, isA<WoltBottomSheetType>());
      expect(type.forceMaxHeight, isTrue);
    });
  });

  group('showSideSheetPane', () {
    Future<void> pumpHost(WidgetTester tester) async {
      setTestSurfaceSize(tester, wide);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showSideSheetPane<void>(
                context: context,
                sideSheet: const SizedWoltSideSheetType(
                  widthFraction: 1,
                  minWidth: 400,
                  maxWidth: 400,
                ),
                // A pane that needs a bounded box: the Expanded would throw
                // in an unbounded, shrink-wrapping page.
                builder: (sheetContext) => Column(
                  children: [
                    const Expanded(
                      child: SizedBox.expand(key: ValueKey('pane-body')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: wide),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('fills a trailing panel of the requested width, full height', (
      tester,
    ) async {
      await pumpHost(tester);

      final body = tester.getRect(find.byKey(const ValueKey('pane-body')));
      expect(body.width, moreOrLessEquals(400, epsilon: 1));
      expect(body.right, moreOrLessEquals(wide.width, epsilon: 1));
      // The Expanded body took the height left above the footer — far more
      // than a shrink-wrapped page would have given it.
      expect(body.height, greaterThan(wide.height / 2));
    });

    testWidgets('dims the page with the shared scrim and closes on pop', (
      tester,
    ) async {
      await pumpHost(tester);

      final context = tester.element(find.text('Open'));
      final scrim = ModalUtils.getModalBarrierColor(
        isDark: Theme.of(context).brightness == Brightness.dark,
        context: context,
      );
      expect(
        find.byWidgetPredicate((w) => w is ModalBarrier && w.color == scrim),
        findsOneWidget,
      );

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pane-body')), findsNothing);
    });
  });
}
