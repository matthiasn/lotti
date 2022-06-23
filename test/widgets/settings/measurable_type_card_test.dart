import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/widgets/settings/measurables/measurable_type_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../widget_test_utils.dart';

void main() {
  group('MeasurableTypeCard Widget Tests - ', () {
    testWidgets('displays measurable data type', (tester) async {
      const testDescription = 'test description';
      const testUnit = 'ml';
      const testDisplayName = 'Water';

      final testItem = MeasurableDataType(
        description: testDescription,
        unitName: testUnit,
        displayName: testDisplayName,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        vectorClock: null,
        version: 1,
        id: 'some-id',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            index: 0,
            item: testItem,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);
      expect(find.text(testDescription), findsOneWidget);
      // expect(find.text(testUnit), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsNothing);
      expect(find.byIcon(MdiIcons.security), findsNothing);
    });
  });
}
