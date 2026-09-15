import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_chip_surface.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  const radius = BorderRadius.all(Radius.circular(24));
  const content = SizedBox(key: ValueKey('content'), width: 120, height: 40);

  Future<void> pump(WidgetTester tester, {required bool blurred}) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Center(
          child: DsGlassChipSurface(
            radius: radius,
            blurred: blurred,
            child: content,
          ),
        ),
        theme: DesignSystemTheme.dark(),
      ),
    );
  }

  ClipRRect clip(WidgetTester tester) => tester.widget<ClipRRect>(
    find.descendant(
      of: find.byType(DsGlassChipSurface),
      matching: find.byType(ClipRRect),
    ),
  );

  testWidgets('a translucent chip blurs the page inside its own clip', (
    tester,
  ) async {
    await pump(tester, blurred: true);

    // The filter sits INSIDE the clip: blurring outside it would smear the
    // page around the chip, which is exactly what the glass must not do.
    final filter = tester.widget<BackdropFilter>(
      find.descendant(
        of: find.byType(ClipRRect),
        matching: find.byType(BackdropFilter),
      ),
    );
    expect(
      filter.filter.toString(),
      contains('${DesignSystemGlassStrip.blurSigma}'),
    );
    expect(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byKey(const ValueKey('content')),
      ),
      findsOneWidget,
      reason: 'the child renders on top of the blurred page',
    );
  });

  testWidgets('an opaque chip skips the blur it could not show through', (
    tester,
  ) async {
    await pump(tester, blurred: false);

    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ClipRRect),
        matching: find.byKey(const ValueKey('content')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('clips to the given radius and wears the floating shadow', (
    tester,
  ) async {
    await pump(tester, blurred: true);

    expect(clip(tester).borderRadius, radius);
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(DsGlassChipSurface),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.boxShadow, DsShadows.floatingSurface);
    expect(decoration.borderRadius, radius);
  });

  testWidgets('takes exactly the size of its child', (tester) async {
    await pump(tester, blurred: true);

    expect(
      tester.getSize(find.byType(DsGlassChipSurface)),
      tester.getSize(find.byKey(const ValueKey('content'))),
      reason: 'the chrome must not widen or heighten the chip it wraps',
    );
  });
}
