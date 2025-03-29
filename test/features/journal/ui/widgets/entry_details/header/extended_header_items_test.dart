import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_items.dart'
    as header_items;

import '../../../../../../test_helper.dart';

void main() {
  group('SwitchListTile', () {
    testWidgets('renders correctly when value is true', (tester) async {
      var valueChanged = false;

      await tester.pumpWidget(
        createTestApp(
          header_items.SwitchListTile(
            title: 'Test Title',
            onPressed: () {
              valueChanged = true;
            },
            value: true,
            icon: Icons.check_box_outline_blank,
            activeIcon: Icons.check_box,
            activeColor: Colors.green,
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);

      await tester.tap(find.byType(ListTile));
      expect(valueChanged, isTrue);
    });

    testWidgets('renders correctly when value is false', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          header_items.SwitchListTile(
            title: 'Test Title',
            onPressed: () {},
            value: false,
            icon: Icons.check_box_outline_blank,
            activeIcon: Icons.check_box,
            activeColor: Colors.green,
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    });
  });
}
