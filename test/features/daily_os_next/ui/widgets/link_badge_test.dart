import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/link_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  Material(child: Center(child: child)),
  mediaQueryData: const MediaQueryData(size: Size(800, 600)),
);

void main() {
  group('LinkBadge', () {
    testWidgets('shows the task name in the info tone and fires onTap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(LinkBadge(label: 'Q3 strategy deck', onTap: () => taps++)),
      );

      final context = tester.element(find.byType(LinkBadge));
      final tokens = context.designTokens;
      final label = tester.widget<Text>(find.text('Q3 strategy deck'));
      expect(label.style?.color, tokens.colors.alert.info.defaultColor);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);

      await tester.tap(find.byType(LinkBadge));
      expect(taps, 1);
    });

    testWidgets('long task names ellipsize inside the 220px cap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LinkBadge(
            label:
                'A very long task name that would otherwise blow way past '
                'the badge width cap',
          ),
        ),
      );

      final badge = tester.getSize(find.byType(LinkBadge));
      expect(badge.width, lessThanOrEqualTo(220));
      expect(tester.takeException(), isNull);
    });
  });
}
