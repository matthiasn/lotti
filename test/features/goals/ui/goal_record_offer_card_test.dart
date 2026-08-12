import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/goals/model/goal_measurable_record_offer.dart';
import 'package:lotti/features/goals/service/goal_measurable_capture_service.dart';
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
import 'package:lotti/features/goals/ui/goal_record_offer_card.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class _MockGoalMeasurableCaptureService extends Mock
    implements GoalMeasurableCaptureService {}

void main() {
  testWidgets(
    'a same-day measurement surfaces the conflict and blocks record',
    (
      tester,
    ) async {
      final db = MockJournalDb();
      final existingAt = DateTime(2026, 8, 11, 9);
      when(
        () => db.getMeasurementsByType(
          type: 'pages',
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) async => [
          MeasurementEntry(
            meta: Metadata(
              id: 'existing',
              createdAt: existingAt,
              updatedAt: existingAt,
              dateFrom: existingAt,
              dateTo: existingAt,
            ),
            data: MeasurementData(
              dateFrom: existingAt,
              dateTo: existingAt,
              value: 15,
              dataTypeId: 'pages',
            ),
          ),
        ],
      );
      final now = DateTime(2026, 8, 12);
      final measurable = MeasurableDataType(
        id: 'pages',
        createdAt: now,
        updatedAt: now,
        displayName: 'Pages read',
        description: '',
        unitName: 'pages',
        version: 1,
        vectorClock: null,
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: GoalRecordOfferCard(
              agentId: 'goal-1',
              agentName: 'Juno',
              measurable: measurable,
              offer: GoalMeasurableRecordOffer(
                sourceMessageId: 'message-1',
                dataTypeId: 'pages',
                measurableName: 'Pages read',
                unitName: 'pages',
                items: [
                  GoalMeasurableRecordItem(
                    day: DateTime.utc(2026, 8, 11),
                    value: 20,
                    estimated: true,
                  ),
                  GoalMeasurableRecordItem(
                    day: DateTime.utc(2026, 8, 12),
                    value: 20,
                    estimated: true,
                  ),
                ],
              ),
            ),
          ),
          overrides: [journalDbProvider.overrideWithValue(db)],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('already logged'), findsOneWidget);
      expect(find.text('Estimated split — edit if needed'), findsNWidgets(2));
      final record = tester.widget<DesignSystemButton>(
        find.widgetWithText(DesignSystemButton, 'Record 2 entries'),
      );
      expect(record.onPressed, isNull);
    },
  );

  testWidgets('confirmation rechecks for a concurrent measurement', (
    tester,
  ) async {
    final db = MockJournalDb();
    final service = _MockGoalMeasurableCaptureService();
    var reads = 0;
    final existingAt = DateTime(2026, 8, 12, 9);
    when(
      () => db.getMeasurementsByType(
        type: 'pages',
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async {
      reads++;
      if (reads == 1) return [];
      return [
        MeasurementEntry(
          meta: Metadata(
            id: 'synced-while-open',
            createdAt: existingAt,
            updatedAt: existingAt,
            dateFrom: existingAt,
            dateTo: existingAt,
          ),
          data: MeasurementData(
            dateFrom: existingAt,
            dateTo: existingAt,
            value: 25,
            dataTypeId: 'pages',
          ),
        ),
      ];
    });
    final now = DateTime(2026, 8, 12);
    final measurable = MeasurableDataType(
      id: 'pages',
      createdAt: now,
      updatedAt: now,
      displayName: 'Pages read',
      description: '',
      unitName: 'pages',
      version: 1,
      vectorClock: null,
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: GoalRecordOfferCard(
            agentId: 'goal-1',
            agentName: 'Juno',
            measurable: measurable,
            offer: GoalMeasurableRecordOffer(
              sourceMessageId: 'message-1',
              dataTypeId: 'pages',
              measurableName: 'Pages read',
              unitName: 'pages',
              items: [
                GoalMeasurableRecordItem(
                  day: DateTime.utc(2026, 8, 12),
                  value: 20,
                  estimated: false,
                ),
              ],
            ),
          ),
        ),
        overrides: [
          journalDbProvider.overrideWithValue(db),
          goalMeasurableCaptureServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final record = tester.widget<DesignSystemButton>(
      find.widgetWithText(DesignSystemButton, 'Record entry'),
    );
    expect(record.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Record entry'));
    await tester.pumpAndSettle();

    expect(reads, 2);
    expect(find.textContaining('already logged'), findsNWidgets(2));
    verifyZeroInteractions(service);
  });
}
