import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/providers/service_providers.dart';
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
  late MockSyncMaintenanceRepository mockSyncMaintenanceRepository;

  Future<void> pumpModal(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ReSyncModalContent(),
        overrides: [
          maintenanceProvider.overrideWithValue(mockMaintenance),
          agentRepositoryProvider.overrideWithValue(mockAgentRepository),
          syncMaintenanceRepositoryProvider.overrideWithValue(
            mockSyncMaintenanceRepository,
          ),
        ],
      ),
    );
    await tester.pump();
  }

  Future<void> selectPreset(
    WidgetTester tester,
    ReSyncRangePreset preset,
  ) async {
    tester
        .widget<DsSegmentedToggle<ReSyncRangePreset>>(
          find.byType(DsSegmentedToggle<ReSyncRangePreset>),
        )
        .onChanged(preset);
    await tester.pump();
  }

  setUpAll(registerAllFallbackValues);

  setUp(() {
    ensureDomainLoggerRegistered();
    mockMaintenance = MockMaintenance();
    mockAgentRepository = MockAgentRepository();
    mockSyncMaintenanceRepository = MockSyncMaintenanceRepository();
    when(
      () => mockSyncMaintenanceRepository.backfillAgentEntityClocks(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSyncMaintenanceRepository.backfillAgentLinkClocks(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMaintenance.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        agentRepository: any(named: 'agentRepository'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async {});
  });

  testWidgets('defaults to Everything and hides custom date fields', (
    tester,
  ) async {
    await pumpModal(tester);

    expect(find.text('Everything'), findsWidgets);
    expect(find.text('Last 30 days'), findsWidgets);
    expect(find.text('Custom'), findsWidgets);
    expect(find.byType(DateTimeField), findsNothing);
  });

  testWidgets(
    'entity choices use compact full-row targets with trailing checkboxes',
    (tester) async {
      await pumpModal(tester);

      for (final (key, label) in [
        (
          const Key('reSyncJournalEntitiesCheckbox'),
          'Journal entities',
        ),
        (
          const Key('reSyncAgentEntitiesCheckbox'),
          'Agent entities',
        ),
      ]) {
        final row = find.byKey(key);
        final checkbox = find.descendant(
          of: row,
          matching: find.byType(DesignSystemCheckbox),
        );
        final text = find.descendant(
          of: row,
          matching: find.text(label),
        );

        expect(
          tester.widget<DesignSystemSelectionRow>(row).type,
          DesignSystemSelectionRowType.multiSelect,
        );
        expect(tester.getSize(row).height, TapTargets.minimum);
        expect(
          tester.getCenter(checkbox).dx,
          greaterThan(tester.getCenter(text).dx),
        );
      }
    },
  );

  testWidgets('starts re-sync with the selected custom interval', (
    tester,
  ) async {
    await pumpModal(tester);
    await selectPreset(tester, ReSyncRangePreset.custom);

    final fields = find
        .byType(DateTimeField)
        .evaluate()
        .map((element) => element.widget as DateTimeField)
        .toList();
    final start = DateTime(2024, 1, 1, 8);
    final end = DateTime(2024, 1, 2, 18, 30);

    fields.first.setDateTime(start);
    fields.last.setDateTime(end);
    await tester.pump();

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    verify(
      () => mockMaintenance.reSyncInterval(
        start: start,
        end: end,
        agentRepository: mockAgentRepository,
        includeJournalEntities: true,
        includeAgentEntities: true,
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  testWidgets('Everything sends the complete historical interval', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 27, 12);

    await withClock(Clock.fixed(now), () async {
      await pumpModal(tester);
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();
    });

    verify(
      () => mockMaintenance.reSyncInterval(
        start: reSyncEverythingStart,
        end: now,
        agentRepository: mockAgentRepository,
        includeJournalEntities: true,
        includeAgentEntities: true,
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  testWidgets('Last 30 days sends a deterministic 30-day interval', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 27, 12);

    await withClock(Clock.fixed(now), () async {
      await pumpModal(tester);
      await selectPreset(tester, ReSyncRangePreset.last30Days);
      expect(find.byType(DateTimeField), findsNothing);
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();
    });

    verify(
      () => mockMaintenance.reSyncInterval(
        start: now.subtract(const Duration(days: 30)),
        end: now,
        agentRepository: mockAgentRepository,
        includeJournalEntities: true,
        includeAgentEntities: true,
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  testWidgets('Custom rejects a range whose start is not before its end', (
    tester,
  ) async {
    await pumpModal(tester);
    await selectPreset(tester, ReSyncRangePreset.custom);

    final fields = find
        .byType(DateTimeField)
        .evaluate()
        .map((element) => element.widget as DateTimeField)
        .toList();
    expect(fields, hasLength(2));

    fields.first.setDateTime(DateTime(2026, 7, 28));
    fields.last.setDateTime(DateTime(2026, 7, 27));
    await tester.pump();

    expect(find.byKey(const Key('reSyncInvalidRangeError')), findsOneWidget);
    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Start'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('Start waits in the modal and reports per-phase progress', (
    tester,
  ) async {
    final completer = Completer<void>();
    when(
      () => mockMaintenance.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        agentRepository: any(named: 'agentRepository'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((invocation) {
      final onProgress =
          invocation.namedArguments[#onProgress] as ReSyncProgressCallback;
      onProgress(
        const ReSyncProgress(
          phase: ReSyncPhase.journalEntities,
          processed: 12,
          total: 25,
          isComplete: false,
        ),
      );
      return completer.future;
    });

    await pumpModal(tester);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(find.byKey(const Key('reSyncProgress')), findsOneWidget);
    expect(find.byKey(const Key('reSyncComplete')), findsNothing);
    expect(find.text('12 / 25'), findsOneWidget);

    completer.complete();
    await tester.pump();

    expect(find.byKey(const Key('reSyncComplete')), findsOneWidget);
  });

  testWidgets('completed phase reports its count and completion state', (
    tester,
  ) async {
    final completer = Completer<void>();
    when(
      () => mockMaintenance.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        agentRepository: any(named: 'agentRepository'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((invocation) {
      final onProgress =
          invocation.namedArguments[#onProgress] as ReSyncProgressCallback;
      onProgress(
        const ReSyncProgress(
          phase: ReSyncPhase.journalEntities,
          processed: 12,
          total: 12,
          isComplete: true,
        ),
      );
      return completer.future;
    });

    await pumpModal(tester);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(find.byKey(const Key('reSyncProgress')), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('12 / 12'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

    completer.complete();
    await tester.pump();
  });

  testWidgets('caps live progress at 100 percent when totals grow stale', (
    tester,
  ) async {
    final completer = Completer<void>();
    when(
      () => mockMaintenance.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        agentRepository: any(named: 'agentRepository'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((invocation) {
      final onProgress =
          invocation.namedArguments[#onProgress] as ReSyncProgressCallback;
      onProgress(
        const ReSyncProgress(
          phase: ReSyncPhase.journalEntities,
          processed: 2,
          total: 1,
          isComplete: false,
        ),
      );
      return completer.future;
    });

    await pumpModal(tester);
    await tester.tap(find.byKey(const Key('reSyncAgentEntitiesCheckbox')));
    await tester.pump();
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('200%'), findsNothing);

    completer.complete();
    await tester.pump();
  });

  testWidgets('failure stays in the modal and can be retried', (tester) async {
    var attempts = 0;
    when(
      () => mockMaintenance.reSyncInterval(
        start: any(named: 'start'),
        end: any(named: 'end'),
        agentRepository: any(named: 'agentRepository'),
        includeJournalEntities: any(named: 'includeJournalEntities'),
        includeAgentEntities: any(named: 'includeAgentEntities'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('enqueue failed');
    });

    await pumpModal(tester);
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(find.byKey(const Key('reSyncFailed')), findsOneWidget);
    expect(find.byKey(const Key('reSyncComplete')), findsNothing);
    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Start'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.byKey(const Key('reSyncFailed')), findsNothing);
    expect(find.byKey(const Key('reSyncComplete')), findsOneWidget);
  });

  testWidgets('uses the localized maintenance label as the modal title', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ReSyncModal.show(context),
            child: const Text('Open'),
          ),
        ),
        overrides: [
          maintenanceProvider.overrideWithValue(mockMaintenance),
          agentRepositoryProvider.overrideWithValue(mockAgentRepository),
          syncMaintenanceRepositoryProvider.overrideWithValue(
            mockSyncMaintenanceRepository,
          ),
        ],
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Message history'), findsWidgets);
    expect(find.text('Re-sync messages'), findsNothing);

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
    await tester.pump();
    expect(find.byKey(const Key('reSyncComplete')), findsOneWidget);

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Done'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ReSyncModalContent), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets(
    'unchecking agent entities excludes agent entities',
    (tester) async {
      await pumpModal(tester);

      await tester.tap(find.byKey(const Key('reSyncAgentEntitiesCheckbox')));
      await tester.pump();
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();

      verify(
        () => mockMaintenance.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
          agentRepository: mockAgentRepository,
          includeJournalEntities: true,
          includeAgentEntities: false,
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'unchecking journal entities excludes journal entities',
    (tester) async {
      await pumpModal(tester);

      await tester.tap(find.byKey(const Key('reSyncJournalEntitiesCheckbox')));
      await tester.pump();
      await tester.tap(find.widgetWithText(DesignSystemButton, 'Start'));
      await tester.pump();

      verify(
        () => mockMaintenance.reSyncInterval(
          start: any(named: 'start'),
          end: any(named: 'end'),
          agentRepository: mockAgentRepository,
          includeJournalEntities: false,
          includeAgentEntities: true,
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    },
  );

  testWidgets('Start disables when neither entity type is selected', (
    tester,
  ) async {
    await pumpModal(tester);

    await tester.tap(find.byKey(const Key('reSyncJournalEntitiesCheckbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reSyncAgentEntitiesCheckbox')));
    await tester.pump();

    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Start'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.byKey(const Key('reSyncSelectAtLeastOneError')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('reSyncJournalEntitiesCheckbox')));
    await tester.pump();

    expect(
      tester
          .widget<DesignSystemButton>(
            find.widgetWithText(DesignSystemButton, 'Start'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const Key('reSyncSelectAtLeastOneError')),
      findsNothing,
    );
  });
}
