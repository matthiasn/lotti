import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/cadence_pill.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const key = ValueKey('overdue');

  Future<void> pump(WidgetTester tester, {VoidCallback? onTap}) =>
      tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => relationshipOverduePill(
              context,
              label: '5 days overdue',
              pillKey: key,
              onTap: onTap,
            ),
          ),
        ),
      );

  testWidgets('says the lapse in the warning tint, by its glyph as well as '
      'its colour, and reads out only', (tester) async {
    await pump(tester);
    final tokens = tester.element(find.byKey(key)).designTokens;

    final pill = tester.widget<DsPill>(find.byKey(key));
    expect(pill.label, '5 days overdue');
    expect(pill.variant, DsPillVariant.tinted);
    expect(pill.color, tokens.colors.alert.warning.defaultColor);
    expect(pill.onTap, isNull);
    expect(pill.trailing, isNull);
    expect(find.byIcon(LottiIcons.warning), findsOneWidget);
  });

  testWidgets('with a way out it is tappable, and a chevron says so', (
    tester,
  ) async {
    var tapped = 0;
    await pump(tester, onTap: () => tapped++);

    expect(
      find.descendant(
        of: find.byKey(key),
        matching: find.byIcon(LottiIcons.chevronRight),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(key));
    expect(tapped, 1);
  });
}
