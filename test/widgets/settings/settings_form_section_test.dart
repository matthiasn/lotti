import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';

import '../../test_helper.dart';

void main() {
  testWidgets(
    'renders the overline header and description above the card children',
    (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: SettingsFormSection(
            title: 'Basic settings',
            description: 'Name and appearance',
            children: [
              Text('first row'),
              Text('second row'),
            ],
          ),
        ),
      );

      expect(find.text('Basic settings'), findsOneWidget);
      expect(find.text('Name and appearance'), findsOneWidget);
      expect(find.text('first row'), findsOneWidget);
      expect(find.text('second row'), findsOneWidget);

      // The header sits above the card content.
      final titleY = tester.getTopLeft(find.text('Basic settings')).dy;
      final firstRowY = tester.getTopLeft(find.text('first row')).dy;
      expect(titleY, lessThan(firstRowY));

      // Children keep their declared order with vertical spacing between.
      final secondRowY = tester.getTopLeft(find.text('second row')).dy;
      expect(firstRowY, lessThan(secondRowY));
    },
  );

  testWidgets('omits the description when not provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const WidgetTestBench(
        child: SettingsFormSection(
          title: 'Color',
          children: [Text('picker')],
        ),
      ),
    );

    expect(find.text('Color'), findsOneWidget);
    expect(find.text('picker'), findsOneWidget);
  });
}
