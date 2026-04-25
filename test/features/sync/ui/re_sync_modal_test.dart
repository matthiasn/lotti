import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

// ignore_for_file: avoid_redundant_argument_values

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMaintenance mockMaintenance;
  late MockAgentRepository mockAgentRepository;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockMaintenance = MockMaintenance();
    mockAgentRepository = MockAgentRepository();
    when(
      () => mockMaintenance.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        agentRepository: any(named: 'agentRepository'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
      ),
    ).thenAnswer((_) async {});
  });

  testWidgets('starts re-sync with selected interval', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ReSyncModalContent(),
        overrides: [
          maintenanceProvider.overrideWithValue(mockMaintenance),
          agentRepositoryProvider.overrideWithValue(mockAgentRepository),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final dateFieldFinder = find.byType(DateTimeField);
    final fields = dateFieldFinder.evaluate().map(
      (element) => element.widget as DateTimeField,
    );
    final start = DateTime(2024, 1, 1, 8, 0);
    final end = DateTime(2024, 1, 2, 18, 30);

    fields.first.setDateTime(start);
    fields.last.setDateTime(end);

    await tester.pump();

    final startButtonFinder = find.widgetWithText(
      LottiSecondaryButton,
      'Start',
    );
    expect(startButtonFinder, findsOneWidget);

    await tester.tap(startButtonFinder);
    await tester.pumpAndSettle();

    verify(
      () => mockMaintenance.reSyncInterval(
        start: start,
        end: end,
        agentRepository: mockAgentRepository,
        includeJournalEntities: true,
        includeAgentEntities: true,
      ),
    ).called(1);
  });

  testWidgets(
    'unchecking agent entities passes includeAgentEntities=false',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ReSyncModalContent(),
          overrides: [
            maintenanceProvider.overrideWithValue(mockMaintenance),
            agentRepositoryProvider.overrideWithValue(mockAgentRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Untick the "Agent entities" checkbox.
      await tester.tap(find.byKey(const Key('reSyncAgentEntitiesCheckbox')));
      await tester.pump();

      final startButtonFinder = find.widgetWithText(
        LottiSecondaryButton,
        'Start',
      );
      expect(startButtonFinder, findsOneWidget);
      await tester.tap(startButtonFinder);
      await tester.pumpAndSettle();

      verify(
        () => mockMaintenance.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
          agentRepository: mockAgentRepository,
          includeJournalEntities: true,
          includeAgentEntities: false,
        ),
      ).called(1);
    },
  );

  testWidgets(
    'unchecking journal entities passes includeJournalEntities=false',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ReSyncModalContent(),
          overrides: [
            maintenanceProvider.overrideWithValue(mockMaintenance),
            agentRepositoryProvider.overrideWithValue(mockAgentRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reSyncJournalEntitiesCheckbox')));
      await tester.pump();

      final startButtonFinder = find.widgetWithText(
        LottiSecondaryButton,
        'Start',
      );
      await tester.tap(startButtonFinder);
      await tester.pumpAndSettle();

      verify(
        () => mockMaintenance.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
          agentRepository: mockAgentRepository,
          includeJournalEntities: false,
          includeAgentEntities: true,
        ),
      ).called(1);
    },
  );

  testWidgets(
    'start button disables when neither entity type is selected',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ReSyncModalContent(),
          overrides: [
            maintenanceProvider.overrideWithValue(mockMaintenance),
            agentRepositoryProvider.overrideWithValue(mockAgentRepository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Untick both checkboxes.
      await tester.tap(find.byKey(const Key('reSyncJournalEntitiesCheckbox')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('reSyncAgentEntitiesCheckbox')));
      await tester.pump();

      final startButton = tester.widget<LottiSecondaryButton>(
        find.widgetWithText(LottiSecondaryButton, 'Start'),
      );
      expect(startButton.onPressed, isNull);
      // The user-visible signal that explains the disabled state.
      expect(
        find.byKey(const Key('reSyncSelectAtLeastOneError')),
        findsOneWidget,
      );

      // Re-tick journal — start should re-enable and the hint disappears.
      await tester.tap(find.byKey(const Key('reSyncJournalEntitiesCheckbox')));
      await tester.pump();
      final startButtonAfter = tester.widget<LottiSecondaryButton>(
        find.widgetWithText(LottiSecondaryButton, 'Start'),
      );
      expect(startButtonAfter.onPressed, isNotNull);
      expect(
        find.byKey(const Key('reSyncSelectAtLeastOneError')),
        findsNothing,
      );
    },
  );

  testWidgets('start button enabled with default dates', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ReSyncModalContent(),
        overrides: [
          maintenanceProvider.overrideWithValue(mockMaintenance),
          agentRepositoryProvider.overrideWithValue(mockAgentRepository),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final startButtonFinder = find.widgetWithText(
      LottiSecondaryButton,
      'Start',
    );
    expect(startButtonFinder, findsOneWidget);

    final startButton = tester.widget<LottiSecondaryButton>(startButtonFinder);
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('default dates set to last 24 hours', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ReSyncModalContent(),
        overrides: [
          maintenanceProvider.overrideWithValue(mockMaintenance),
          agentRepositoryProvider.overrideWithValue(mockAgentRepository),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final dateFieldFinder = find.byType(DateTimeField);
    final fields = dateFieldFinder
        .evaluate()
        .map((element) => element.widget as DateTimeField)
        .toList();

    expect(fields.length, 2);

    final dateFrom = fields.first.dateTime;
    final dateTo = fields.last.dateTime;

    expect(dateFrom, isNotNull);
    expect(dateTo, isNotNull);

    // Verify dateFrom is approximately 24 hours before dateTo
    final difference = dateTo!.difference(dateFrom!);
    expect(difference.inHours, 24);
    expect(difference.inMinutes, closeTo(24 * 60, 1));

    // Verify dateTo is a recent date (the widget initializes with
    // DateTime.now() internally, so we just check it's reasonable)
    final referenceDate = DateTime(2020, 1, 1);
    expect(
      dateTo.isAfter(referenceDate),
      isTrue,
      reason: 'dateTo should be a recent date',
    );
  });
}
