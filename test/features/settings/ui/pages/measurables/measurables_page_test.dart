import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;

  Future<void> pumpMeasurablesPage(
    WidgetTester tester, {
    required List<MeasurableDataType> measurables,
  }) async {
    mockJournalDb = mockJournalDbWithMeasurableTypes(measurables);

    final mockUpdateNotifications = MockUpdateNotifications();
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());

    await getIt.reset();
    getIt
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<JournalDb>(mockJournalDb);
    ensureThemingServicesRegistered();

    await tester.pumpWidget(
      makeTestableWidget(
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 1000,
            maxWidth: 1000,
          ),
          child: const MeasurablesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(getIt.reset);

  group('MeasurablesPage', () {
    group('basic rendering', () {
      testWidgets('displays measurable names', (tester) async {
        await pumpMeasurablesPage(
          tester,
          measurables: [measurableWater, measurableChocolate],
        );

        expect(find.text(measurableWater.displayName), findsOneWidget);
        expect(find.text(measurableChocolate.displayName), findsOneWidget);
      });

      testWidgets('displays description as subtitle', (tester) async {
        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        expect(find.text(measurableWater.description), findsOneWidget);
      });

      testWidgets('displays unit name when description is empty', (
        tester,
      ) async {
        final noDescMeasurable = measurableWater.copyWith(
          displayName: 'Steps',
          description: '',
          unitName: 'steps',
        );
        await pumpMeasurablesPage(tester, measurables: [noDescMeasurable]);

        expect(find.text('steps'), findsOneWidget);
      });

      testWidgets('displays trending up icon', (tester) async {
        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
      });

      testWidgets('displays chevron trailing icon', (tester) async {
        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      });
    });

    group('status icons', () {
      testWidgets('shows lock icon when private', (tester) async {
        final privateMeasurable = measurableWater.copyWith(private: true);
        await pumpMeasurablesPage(tester, measurables: [privateMeasurable]);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('hides lock icon when not private', (tester) async {
        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        expect(find.byIcon(Icons.lock_outline), findsNothing);
      });

      testWidgets('shows star icon when favorite', (tester) async {
        final favoriteMeasurable = measurableWater.copyWith(favorite: true);
        await pumpMeasurablesPage(tester, measurables: [favoriteMeasurable]);

        expect(find.byIcon(Icons.star), findsOneWidget);
      });

      testWidgets('hides star icon when not favorite', (tester) async {
        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        expect(find.byIcon(Icons.star), findsNothing);
      });

      testWidgets('shows both private and favorite icons', (tester) async {
        final fullMeasurable = measurableWater.copyWith(
          private: true,
          favorite: true,
        );
        await pumpMeasurablesPage(tester, measurables: [fullMeasurable]);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
      });
    });

    group('dividers', () {
      testWidgets('shows dividers between items but not after last', (
        tester,
      ) async {
        await pumpMeasurablesPage(
          tester,
          measurables: [
            measurableWater,
            measurableChocolate,
            measurableCoverage,
          ],
        );

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(3));

        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.showDivider, isTrue);
        expect(second.showDivider, isTrue);
        expect(third.showDivider, isFalse);
      });

      testWidgets('single item has no divider', (tester) async {
        await pumpMeasurablesPage(tester, measurables: [measurableWater]);

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.showDivider, isFalse);
      });
    });
  });
}
