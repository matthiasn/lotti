import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<BuildContext> pump(WidgetTester tester, Size size) async {
    setTestSurfaceSize(tester, size);
    late BuildContext captured;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) {
            captured = context;
            return const DetailContentWidth(
              child: SizedBox(key: ValueKey('content'), height: 10),
            );
          },
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
        detailContentInsets(context),
        EdgeInsets.symmetric(horizontal: gutter),
      );
    });

    testWidgets('on a desktop-wide window it centres a column capped at the '
        'reading measure', (tester) async {
      final context = await pump(tester, const Size(1280, 800));

      final gutter = context.designTokens.spacing.step5;
      expect(
        detailContentInsets(context),
        EdgeInsets.symmetric(
          horizontal: gutter + (1280 - kDetailContentMaxWidth) / 2,
        ),
      );
    });

    testWidgets('a desktop window narrower than the measure keeps the plain '
        'gutter rather than a negative centring', (tester) async {
      final context = await pump(
        tester,
        const Size(kDesktopBreakpoint, 800),
      );

      final gutter = context.designTokens.spacing.step5;
      expect(
        detailContentInsets(context),
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

      final insets = detailContentInsets(context);
      final content = find.byKey(const ValueKey('content'));
      expect(tester.getSize(content).width, 1280 - insets.horizontal);
      expect(tester.getTopLeft(content).dx, insets.left);
      expect(
        tester.getSize(content).width,
        kDetailContentMaxWidth - 2 * context.designTokens.spacing.step5,
      );
    });
  });
}
