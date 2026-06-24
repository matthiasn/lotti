import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/labels/ui/widgets/category_selection_chip.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) => makeTestableWidgetNoScroll(
    Theme(
      data: DesignSystemTheme.dark(),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('renders the category name in a tinted DsPill', (tester) async {
    await tester.pumpWidget(
      wrap(
        CategorySelectionChip(
          name: 'Work',
          color: const Color(0xFF1F7963),
          onRemove: () {},
          removeTooltip: 'Remove',
        ),
      ),
    );

    expect(find.text('Work'), findsOneWidget);
    final pill = tester.widget<DsPill>(find.byType(DsPill));
    expect(pill.variant, DsPillVariant.tinted);
    expect(pill.color, const Color(0xFF1F7963));
  });

  testWidgets('tapping the ✕ invokes onRemove', (tester) async {
    var removed = 0;
    await tester.pumpWidget(
      wrap(
        CategorySelectionChip(
          name: 'Work',
          color: const Color(0xFF1F7963),
          onRemove: () => removed++,
          removeTooltip: 'Remove',
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(removed, 1);
  });

  testWidgets('the ✕ carries the remove tooltip', (tester) async {
    await tester.pumpWidget(
      wrap(
        CategorySelectionChip(
          name: 'Work',
          color: const Color(0xFF1F7963),
          onRemove: () {},
          removeTooltip: 'Remove Work',
        ),
      ),
    );

    expect(find.byTooltip('Remove Work'), findsOneWidget);
  });
}
