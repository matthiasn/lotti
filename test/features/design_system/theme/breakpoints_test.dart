import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';

void main() {
  group('isDesktopLayout', () {
    Future<bool> resolveAtWidth(WidgetTester tester, double width) async {
      late bool result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(
            builder: (context) {
              result = isDesktopLayout(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('is mobile below the breakpoint', (tester) async {
      expect(await resolveAtWidth(tester, kDesktopBreakpoint - 1), isFalse);
    });

    testWidgets('switches to desktop exactly at the breakpoint', (
      tester,
    ) async {
      expect(await resolveAtWidth(tester, kDesktopBreakpoint), isTrue);
    });

    testWidgets('stays desktop above the breakpoint', (tester) async {
      expect(await resolveAtWidth(tester, kDesktopBreakpoint + 400), isTrue);
    });
  });
}
