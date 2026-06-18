import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/motion/staggered_entrance.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const k0 = Key('section-0');
  const k1 = Key('section-1');
  const k2 = Key('section-2');

  List<Widget> sections() => const [
    SizedBox(key: k0, height: 24, width: 120),
    SizedBox(key: k1, height: 24, width: 120),
    SizedBox(key: k2, height: 24, width: 120),
  ];

  testWidgets('renders every child and wraps each in an entrance animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(StaggeredEntrance(children: sections())),
    );

    // All children are in the tree from the first frame (they fade in via
    // opacity, they are not gated out).
    expect(find.byKey(k0), findsOneWidget);
    expect(find.byKey(k1), findsOneWidget);
    expect(find.byKey(k2), findsOneWidget);

    // Each child is wrapped in a flutter_animate Animate driving the entrance.
    expect(find.byType(Animate), findsNWidgets(3));

    await tester.pumpAndSettle();
    // Still present once the cascade settles.
    expect(find.byKey(k2), findsOneWidget);
  });

  testWidgets('reduced motion renders a plain column with no entrance', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: StaggeredEntrance(children: sections()),
          ),
        ),
      ),
    );

    expect(find.byKey(k0), findsOneWidget);
    expect(find.byKey(k1), findsOneWidget);
    expect(find.byKey(k2), findsOneWidget);
    // No entrance animations are constructed under reduced motion.
    expect(find.byType(Animate), findsNothing);
  });
}
