import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/status_segmented_control.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HabitDisplayFilter?> pumpAndTap(
    WidgetTester tester, {
    required HabitDisplayFilter selected,
    required String tapLabel,
  }) async {
    HabitDisplayFilter? captured;
    await tester.pumpWidget(
      makeTestableWidget(
        Builder(
          builder: (context) {
            return HabitStatusSegmentedControl(
              filter: selected,
              onValueChanged: (f) => captured = f,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(tapLabel));
    await tester.pump();
    return captured;
  }

  testWidgets('renders all four filter labels', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const HabitStatusSegmentedControl(
          filter: HabitDisplayFilter.openNow,
          onValueChanged: _noop,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('due'), findsOneWidget);
    expect(find.text('later'), findsOneWidget);
    expect(find.text('done'), findsOneWidget);
    expect(find.text('all'), findsOneWidget);
  });

  testWidgets('the selected pill has the interactive-teal background', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const HabitStatusSegmentedControl(
          filter: HabitDisplayFilter.completed,
          onValueChanged: _noop,
        ),
      ),
    );
    await tester.pump();

    final tokens = Theme.of(
      tester.element(find.text('due')),
    ).extension<DsTokens>()!;

    final dueMaterial = tester
        .widgetList<Material>(
          find.ancestor(of: find.text('due'), matching: find.byType(Material)),
        )
        .first;
    final doneMaterial = tester
        .widgetList<Material>(
          find.ancestor(of: find.text('done'), matching: find.byType(Material)),
        )
        .first;

    expect(doneMaterial.color, tokens.colors.interactive.enabled);
    expect(dueMaterial.color, isNot(tokens.colors.interactive.enabled));
  });

  testWidgets('tapping each pill emits the matching filter', (tester) async {
    expect(
      await pumpAndTap(
        tester,
        selected: HabitDisplayFilter.all,
        tapLabel: 'due',
      ),
      HabitDisplayFilter.openNow,
    );
    expect(
      await pumpAndTap(
        tester,
        selected: HabitDisplayFilter.openNow,
        tapLabel: 'later',
      ),
      HabitDisplayFilter.pendingLater,
    );
    expect(
      await pumpAndTap(
        tester,
        selected: HabitDisplayFilter.openNow,
        tapLabel: 'done',
      ),
      HabitDisplayFilter.completed,
    );
    expect(
      await pumpAndTap(
        tester,
        selected: HabitDisplayFilter.openNow,
        tapLabel: 'all',
      ),
      HabitDisplayFilter.all,
    );
  });
}

void _noop(HabitDisplayFilter? _) {}
