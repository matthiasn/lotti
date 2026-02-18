import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/settings/ui/widgets/measurables/measurable_type_card.dart';
import 'package:lotti/get_it.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('MeasurableTypeCard', () {
    tearDown(getIt.reset);

    final baseItem = MeasurableDataType(
      description: 'test description',
      unitName: 'ml',
      displayName: 'Water',
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
      version: 1,
      id: 'measurable-123',
    );

    Future<void> pumpCard(
      WidgetTester tester, {
      bool? private,
      bool? favorite,
      String? displayName,
    }) async {
      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            item: baseItem.copyWith(
              private: private,
              favorite: favorite,
              displayName: displayName ?? baseItem.displayName,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('displays the item displayName', (tester) async {
      await pumpCard(tester);
      expect(find.text('Water'), findsOneWidget);
    });

    testWidgets('displays a different displayName', (tester) async {
      await pumpCard(tester, displayName: 'Steps');
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('Water'), findsNothing);
    });

    // Parameterized icon visibility tests covering all flag combinations.
    // Visibility widget with visible=false replaces child with SizedBox.shrink,
    // so the icon is removed from the tree entirely.
    final iconCases = <({bool? private, bool? favorite, String label})>[
      (private: null, favorite: null, label: 'neither private nor favorite'),
      (private: false, favorite: false, label: 'explicitly not private/fav'),
      (private: true, favorite: null, label: 'private only'),
      (private: null, favorite: true, label: 'favorite only'),
      (private: true, favorite: true, label: 'both private and favorite'),
    ];

    for (final c in iconCases) {
      testWidgets('icon visibility: ${c.label}', (tester) async {
        await pumpCard(tester, private: c.private, favorite: c.favorite);

        expect(
          find.byIcon(MdiIcons.security),
          c.private == true ? findsOneWidget : findsNothing,
          reason: 'security icon for ${c.label}',
        );
        expect(
          find.byIcon(MdiIcons.star),
          c.favorite == true ? findsOneWidget : findsNothing,
          reason: 'star icon for ${c.label}',
        );
      });
    }
  });
}
