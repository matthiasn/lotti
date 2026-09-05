import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_composer_width.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  const marker = Key('composer');

  Widget subject(Size size) => makeTestableWidgetNoScroll(
    const Scaffold(
      body: SizedBox.expand(),
      bottomNavigationBar: EvolutionComposerWidth(
        child: SizedBox(key: marker, height: 64),
      ),
    ),
    mediaQueryData: MediaQueryData(size: size),
  );

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject(size));
    await tester.pumpAndSettle();
  }

  group('EvolutionComposerWidth', () {
    testWidgets('caps the composer at the shared reading measure on a wide '
        'window, so it lines up with the transcript above it', (tester) async {
      await pumpAt(tester, const Size(1600, 900));

      expect(
        tester.getSize(find.byKey(marker)).width,
        lessThanOrEqualTo(kDetailContentMaxWidth),
      );
    });

    testWidgets('takes its height from the child — the regression that made '
        'the bar swallow the page and hide the conversation', (tester) async {
      await pumpAt(tester, const Size(1600, 900));

      // A both-axes centre (DetailContentWidth) in this slot expands to the
      // full window height, leaving the body zero height and the input
      // floating in the middle of an empty screen.
      final barHeight = tester
          .getSize(find.byType(EvolutionComposerWidth))
          .height;
      expect(barHeight, closeTo(64, 1));
    });

    testWidgets('spans the full width on a phone, where the measure would '
        'only waste the little space there is', (tester) async {
      const width = 390.0;
      expect(width, lessThan(kDesktopBreakpoint));
      await pumpAt(tester, const Size(width, 844));

      // Full width minus the standard gutter on both sides.
      expect(tester.getSize(find.byKey(marker)).width, greaterThan(width - 80));
    });
  });
}
