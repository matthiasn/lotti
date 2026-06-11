import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/category_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpChip(WidgetTester tester, DayAgentCategory category) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(body: CategoryChip(category: category)),
      ),
    );
    await tester.pump();
  }

  testWidgets('only the swatch dot carries the category color', (
    tester,
  ) async {
    await pumpChip(
      tester,
      const DayAgentCategory(id: 'c1', name: 'Work', colorHex: '#4285F4'),
    );

    expect(find.text('Work'), findsOneWidget);

    // The swatch dot carries the parsed color at full opacity.
    final hasSwatch = tester
        .widgetList<Container>(find.byType(Container))
        .any(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == const Color(0xFF4285F4),
        );
    expect(hasSwatch, isTrue);

    // The label stays neutral: category colors are user data, so a tinted
    // label/pill would collide with the fixed status-badge palette.
    final context = tester.element(find.text('Work'));
    final tokens = context.designTokens;
    final text = tester.widget<Text>(find.text('Work'));
    expect(text.style?.color, tokens.colors.text.mediumEmphasis);
    expect(text.style?.color, isNot(const Color(0xFF4285F4)));
  });

  testWidgets('invalid hex falls back to a grey dot without throwing', (
    tester,
  ) async {
    await pumpChip(
      tester,
      const DayAgentCategory(id: 'c2', name: 'Mystery', colorHex: 'zzz'),
    );

    expect(find.text('Mystery'), findsOneWidget);
    final hasGreySwatch = tester
        .widgetList<Container>(find.byType(Container))
        .any(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == Colors.grey,
        );
    expect(hasGreySwatch, isTrue);
    expect(tester.takeException(), isNull);
  });
}
