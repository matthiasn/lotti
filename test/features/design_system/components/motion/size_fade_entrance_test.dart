import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_entrance.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('reveals inserted content progressively', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const SizeFadeEntrance(
          child: SizedBox(key: Key('content'), height: 120),
        ),
      ),
    );

    var transition = tester.widget<SizeTransition>(
      find.byType(SizeTransition),
    );
    expect(transition.sizeFactor.value, 0);

    await tester.pump(const Duration(milliseconds: 100));
    transition = tester.widget<SizeTransition>(find.byType(SizeTransition));
    expect(transition.sizeFactor.value, inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 200));
    transition = tester.widget<SizeTransition>(find.byType(SizeTransition));
    expect(transition.sizeFactor.value, 1);
    expect(tester.getSize(find.byKey(const Key('content'))).height, 120);
  });

  testWidgets('existing content and reduced motion resolve immediately', (
    tester,
  ) async {
    for (final scenario in <({bool animate, bool reduceMotion})>[
      (animate: false, reduceMotion: false),
      (animate: true, reduceMotion: true),
    ]) {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          SizeFadeEntrance(
            key: ValueKey(scenario),
            animate: scenario.animate,
            child: const SizedBox(height: 80),
          ),
          mediaQueryData: phoneMediaQueryData.copyWith(
            disableAnimations: scenario.reduceMotion,
          ),
        ),
      );

      final transition = tester.widget<SizeTransition>(
        find.byType(SizeTransition),
      );
      expect(transition.sizeFactor.value, 1, reason: '$scenario');
    }
  });
}
