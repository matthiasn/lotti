import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  /// Pumps the widget on a [size] window; [paneWidth] narrows the parent the
  /// way a list/detail split's detail pane does.
  Future<BuildContext> pump(
    WidgetTester tester,
    Size size, {
    double? paneWidth,
  }) async {
    setTestSurfaceSize(tester, size);
    late BuildContext captured;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: paneWidth ?? size.width,
            child: Builder(
              builder: (context) {
                captured = context;
                return const DetailContentWidth(
                  child: SizedBox(key: ValueKey('content'), height: 10),
                );
              },
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(size: size),
      ),
    );
    await tester.pump();
    return captured;
  }

  group('detailContentInsets', () {
    testWidgets('on a phone it is the plain content gutter', (tester) async {
      final context = await pump(tester, const Size(400, 800));

      final gutter = context.designTokens.spacing.step5;
      expect(
        detailContentInsets(context, availableWidth: 400),
        EdgeInsets.symmetric(horizontal: gutter),
      );
    });

    testWidgets('on a desktop-wide window it centres a column capped at the '
        'reading measure', (tester) async {
      final context = await pump(tester, const Size(1280, 800));

      final gutter = context.designTokens.spacing.step5;
      expect(
        detailContentInsets(context, availableWidth: 1280),
        EdgeInsets.symmetric(
          horizontal: gutter + (1280 - kDetailContentMaxWidth) / 2,
        ),
      );
    });

    testWidgets('inside a pane narrower than the measure it centres on the '
        'pane, not the window — the split must not over-inset its detail', (
      tester,
    ) async {
      final context = await pump(tester, const Size(1280, 800));

      final gutter = context.designTokens.spacing.step5;
      expect(
        detailContentInsets(context, availableWidth: 848),
        EdgeInsets.symmetric(horizontal: gutter),
      );
      expect(
        detailContentInsets(context, availableWidth: 1100),
        EdgeInsets.symmetric(
          horizontal: gutter + (1100 - kDetailContentMaxWidth) / 2,
        ),
      );
    });

    testWidgets('an unbounded parent gets the plain gutter', (tester) async {
      final context = await pump(tester, const Size(1280, 800));

      final gutter = context.designTokens.spacing.step5;
      expect(
        detailContentInsets(context, availableWidth: double.infinity),
        EdgeInsets.symmetric(horizontal: gutter),
      );
    });

    testWidgets('a window narrower than the breakpoint keeps the plain gutter '
        'whatever width is available', (tester) async {
      final context = await pump(
        tester,
        const Size(kDesktopBreakpoint - 1, 800),
      );

      final gutter = context.designTokens.spacing.step5;
      expect(
        detailContentInsets(context, availableWidth: 2000),
        EdgeInsets.symmetric(horizontal: gutter),
      );
    });
  });

  group('DetailContentWidth', () {
    testWidgets('spans the phone width inside the gutter', (tester) async {
      final context = await pump(tester, const Size(400, 800));

      final gutter = context.designTokens.spacing.step5;
      final content = find.byKey(const ValueKey('content'));
      expect(tester.getSize(content).width, 400 - 2 * gutter);
      expect(tester.getTopLeft(content).dx, gutter);
    });

    testWidgets('caps and centres the content on a wide window — the same '
        'geometry detailContentInsets describes', (tester) async {
      final context = await pump(tester, const Size(1280, 800));

      final insets = detailContentInsets(context, availableWidth: 1280);
      final content = find.byKey(const ValueKey('content'));
      expect(tester.getSize(content).width, 1280 - insets.horizontal);
      expect(tester.getTopLeft(content).dx, insets.left);
      expect(
        tester.getSize(content).width,
        kDetailContentMaxWidth - 2 * context.designTokens.spacing.step5,
      );
    });

    testWidgets("in a detail pane narrower than the measure it uses the pane's "
        'width inside the gutter', (tester) async {
      final context = await pump(
        tester,
        const Size(1280, 800),
        paneWidth: 848,
      );

      final gutter = context.designTokens.spacing.step5;
      final content = find.byKey(const ValueKey('content'));
      expect(tester.getSize(content).width, 848 - 2 * gutter);
      expect(tester.getTopLeft(content).dx, gutter);
    });
  });
}
