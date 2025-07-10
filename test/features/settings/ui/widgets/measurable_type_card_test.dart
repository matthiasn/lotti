import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/settings/ui/widgets/measurables/measurable_type_card.dart';
import 'package:lotti/get_it.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('MeasurableTypeCard Widget Tests - ', () {
    setUp(() {});
    tearDown(getIt.reset);

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

    testWidgets('displays measurable data type with unit', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(MeasurableTypeCard(item: testItem)),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsNothing);
      expect(find.byIcon(MdiIcons.security), findsNothing);
    });

    testWidgets('displays measurable data type without unit', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            item: testItem.copyWith(unitName: ''),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsNothing);
      expect(find.byIcon(MdiIcons.security), findsNothing);
    });

    testWidgets('displays private measurable data type with unit',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            item: testItem.copyWith(private: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsNothing);
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });

    testWidgets('displays starred measurable data type with unit',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            item: testItem.copyWith(favorite: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsOneWidget);
      expect(find.byIcon(MdiIcons.security), findsNothing);
    });

    testWidgets('displays private starred measurable data type with unit',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            item: testItem.copyWith(
              favorite: true,
              private: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsOneWidget);
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });

    testWidgets(
        'displays private starred measurable data type with unit and '
        'aggregation type daily sum', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            item: testItem.copyWith(
              favorite: true,
              private: true,
              aggregationType: AggregationType.dailySum,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsOneWidget);
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });

    testWidgets(
        'displays private starred measurable data type with unit and '
        'aggregation type daily max', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            item: testItem.copyWith(
              favorite: true,
              private: true,
              aggregationType: AggregationType.dailyMax,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsOneWidget);
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });

    testWidgets(
        'displays private starred measurable data type with unit and '
        'aggregation type daily avg', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            item: testItem.copyWith(
              favorite: true,
              private: true,
              aggregationType: AggregationType.dailyAvg,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsOneWidget);
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });

    testWidgets(
        'displays private starred measurable data type with unit and '
        'aggregation type none', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          MeasurableTypeCard(
            item: testItem.copyWith(
              favorite: true,
              private: true,
              aggregationType: AggregationType.none,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testDisplayName), findsOneWidget);

      expect(find.byIcon(MdiIcons.star), findsOneWidget);
      expect(find.byIcon(MdiIcons.security), findsOneWidget);
    });
  });
}
