import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/ui/widgets/habits_tool_button.dart';

import '../../../../widget_test_utils.dart';

void main() {
  /// Pumps a [HabitsToolButton] inside the standard testable scaffold.
  Future<void> pumpButton(
    WidgetTester tester, {
    required bool active,
    VoidCallback? onPressed,
    String semanticLabel = 'Search habits',
    String? tooltip,
  }) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitsToolButton(
          icon: Icons.search,
          active: active,
          onPressed: onPressed ?? () {},
          semanticLabel: semanticLabel,
          tooltip: tooltip,
        ),
      ),
    );
  }

  /// Reads the [Icon] widget's resolved color for the tool button.
  Color iconColor(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(Icons.search)).color!;

  /// Reads the [Material] color backing the circular toggle. The button's own
  /// Material is the nearest ancestor of the icon (Scaffold/MaterialApp add
  /// outer Materials), so [find.ancestor] is ordered nearest-first.
  Color materialColor(WidgetTester tester) => tester
      .widget<Material>(
        find
            .ancestor(
              of: find.byIcon(Icons.search),
              matching: find.byType(Material),
            )
            .first,
      )
      .color!;

  testWidgets('renders the provided icon', (tester) async {
    await pumpButton(tester, active: false);

    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('tapping invokes onPressed', (tester) async {
    var taps = 0;
    await pumpButton(tester, active: false, onPressed: () => taps++);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('active and inactive states use different colors', (
    tester,
  ) async {
    final iconColors = <bool, Color>{};
    final materialColors = <bool, Color>{};

    for (final active in [true, false]) {
      await pumpButton(tester, active: active);
      iconColors[active] = iconColor(tester);
      materialColors[active] = materialColor(tester);
    }

    // Active vs inactive must be visually distinct: both the icon ink and the
    // backing Material fill change with the toggle state.
    expect(
      iconColors[true],
      isNot(iconColors[false]),
      reason: 'icon color should differ between active and inactive',
    );
    expect(
      materialColors[true],
      isNot(materialColors[false]),
      reason: 'Material fill should differ between active and inactive',
    );
    // Inactive fill is transparent; active fill is an opaque accent surface.
    expect(materialColors[false], Colors.transparent);
    expect(materialColors[true], isNot(Colors.transparent));
  });

  testWidgets('exposes Semantics with selected matching active and the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    for (final active in [true, false]) {
      await pumpButton(tester, active: active);

      // The semantic label is exposed and findable.
      expect(find.bySemanticsLabel('Search habits'), findsOneWidget);

      // The Semantics node reports button role, a selected state that mirrors
      // the active flag, and the supplied label. isSemantics is non-exhaustive
      // so InkWell's tap/focus actions don't fail the match.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Search habits')),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: active,
          label: 'Search habits',
        ),
      );
    }

    handle.dispose();
  });

  testWidgets('renders a Tooltip with the given message when provided', (
    tester,
  ) async {
    await pumpButton(tester, active: false, tooltip: 'Search');

    final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
    expect(
      tooltips.where((t) => t.message == 'Search'),
      isNotEmpty,
    );
  });

  testWidgets('renders no Tooltip when tooltip is null', (tester) async {
    await pumpButton(tester, active: false);

    expect(find.byType(Tooltip), findsNothing);
  });
}
