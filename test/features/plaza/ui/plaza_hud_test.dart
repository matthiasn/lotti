import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/plaza_hud.dart';

import '../../../widget_test_utils.dart';

void main() {
  late int walks;
  late int overviews;
  late int homes;

  setUp(() {
    walks = 0;
    overviews = 0;
    homes = 0;
  });

  Widget host({String? toast, String? walkChip}) => makeTestableWidget2(
    Scaffold(
      body: PlazaHud(
        projectLabel: 'Project Waddle',
        taskCount: 28,
        weekCount: 6,
        attentionCount: 4,
        onMorningWalk: () => walks++,
        onOverview: () => overviews++,
        onHome: () => homes++,
        toast: toast,
        walkChip: walkChip,
      ),
    ),
    mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
  );

  testWidgets('shows the project, the counts and the legends', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(find.text('Project Waddle — plaza'), findsOneWidget);
    expect(find.text('28 tasks · 6 weeks · 4 need attention'), findsOneWidget);
    for (final key in ['WASD', 'Tab', 'H', 'M', '/', '⌫']) {
      expect(find.text(key), findsOneWidget);
    }
    for (final state in ['in progress', 'open', 'blocked', 'overdue', 'done']) {
      expect(find.text(state), findsOneWidget);
    }
  });

  testWidgets('the three buttons fire their callbacks', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Morning walk'));
    await tester.tap(find.text('Overview'));
    await tester.tap(find.text('Home'));
    expect((walks, overviews, homes), (1, 1, 1));
  });

  testWidgets('toast and walk chip appear only when set', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Fuel the shuttle'), findsNothing);
    await tester.pumpWidget(
      host(toast: 'Fuel the shuttle', walkChip: 'Morning walk · stop 2 of 5'),
    );
    expect(find.text('Fuel the shuttle'), findsOneWidget);
    expect(find.text('Morning walk · stop 2 of 5'), findsOneWidget);
    // Neither blocks the world underneath.
    expect(
      find.ancestor(
        of: find.text('Fuel the shuttle'),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });
}
