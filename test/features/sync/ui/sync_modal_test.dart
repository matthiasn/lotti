import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class MockSyncMaintenanceRepository extends Mock
    implements SyncMaintenanceRepository {}

class SpySyncController extends SyncMaintenanceController {
  SpySyncController();

  static void Function(Set<SyncStep> steps)? onSyncAll;

  @override
  Future<void> syncAll({required Set<SyncStep> selectedSteps}) {
    onSyncAll?.call(selectedSteps);
    return super.syncAll(selectedSteps: selectedSteps);
  }
}

/// Returns a fixed [SyncState] from [build] and no-ops the real sync work, so
/// progress-view rendering can be driven entirely from the test.
class TestSyncController extends SyncMaintenanceController {
  TestSyncController(this._initialState);

  final SyncState _initialState;

  @override
  SyncState build() => _initialState;

  @override
  Future<void> syncAll({required Set<SyncStep> selectedSteps}) async {}

  @override
  void reset() {}
}

/// Keeps [syncAll] pending until [complete] is called so the modal stays on
/// the progress page; [reset] records whether the Done button invoked it.
class _PendingSyncController extends SyncMaintenanceController {
  _PendingSyncController(this.pendingState);

  final SyncState pendingState;
  final Completer<void> _completer = Completer<void>();

  bool resetCalled = false;

  @override
  SyncState build() => const SyncState();

  @override
  Future<void> syncAll({required Set<SyncStep> selectedSteps}) async {
    state = pendingState.copyWith(selectedSteps: selectedSteps);
    return _completer.future;
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  void reset() {
    resetCalled = true;
    state = const SyncState();
  }
}

void main() {
  late MockSyncMaintenanceRepository mockSyncMaintenanceRepository;
  late MockDomainLogger mockLoggingService;
  late AppLocalizations messages;

  setUpAll(() {
    // Register a fallback value for StackTrace if it's used by the mock
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(<SyncStep>{});
  });

  setUp(() {
    mockSyncMaintenanceRepository = MockSyncMaintenanceRepository();
    mockLoggingService = MockDomainLogger();
    messages = AppLocalizationsEn(); // Using English for tests

    const totalsByStep = <SyncStep, int>{
      SyncStep.measurables: 5,
      SyncStep.labels: 6,
      SyncStep.categories: 7,
      SyncStep.dashboards: 8,
      SyncStep.habits: 9,
      SyncStep.aiSettings: 10,
      SyncStep.backfillAgentEntityClocks: 11,
      SyncStep.backfillAgentLinkClocks: 12,
      SyncStep.agentEntities: 3,
      SyncStep.agentLinks: 2,
    };

    Future<void> simulateStep(
      SyncStep step,
      Invocation invocation,
    ) async {
      final onProgress =
          invocation.namedArguments[const Symbol('onProgress')]
              as void Function(double)?;
      final onDetailedProgress =
          invocation.namedArguments[const Symbol('onDetailedProgress')]
              as void Function(int processed, int total)?;
      final total = totalsByStep[step] ?? 0;

      onDetailedProgress?.call(0, total);
      if (total > 0) {
        onProgress?.call(0);
        onDetailedProgress?.call(total, total);
      }
      onProgress?.call(1);
    }

    // Stub all repository methods to return successful futures
    when(
      () => mockSyncMaintenanceRepository.syncMeasurables(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer(
      (invocation) => simulateStep(SyncStep.measurables, invocation),
    );
    when(
      () => mockSyncMaintenanceRepository.syncLabels(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer(
      (invocation) => simulateStep(SyncStep.labels, invocation),
    );
    when(
      () => mockSyncMaintenanceRepository.syncCategories(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer(
      (invocation) => simulateStep(SyncStep.categories, invocation),
    );
    when(
      () => mockSyncMaintenanceRepository.syncDashboards(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer(
      (invocation) => simulateStep(SyncStep.dashboards, invocation),
    );
    when(
      () => mockSyncMaintenanceRepository.syncHabits(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((invocation) => simulateStep(SyncStep.habits, invocation));
    when(
      () => mockSyncMaintenanceRepository.syncAiSettings(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer(
      (invocation) => simulateStep(SyncStep.aiSettings, invocation),
    );
    when(
      () => mockSyncMaintenanceRepository.syncAgentEntities(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer(
      (invocation) => simulateStep(SyncStep.agentEntities, invocation),
    );
    when(
      () => mockSyncMaintenanceRepository.syncAgentLinks(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer(
      (invocation) => simulateStep(SyncStep.agentLinks, invocation),
    );
    when(
      () => mockSyncMaintenanceRepository.backfillAgentEntityClocks(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer(
      (invocation) =>
          simulateStep(SyncStep.backfillAgentEntityClocks, invocation),
    );
    when(
      () => mockSyncMaintenanceRepository.backfillAgentLinkClocks(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer(
      (invocation) =>
          simulateStep(SyncStep.backfillAgentLinkClocks, invocation),
    );

    when(
      () => mockSyncMaintenanceRepository.fetchTotalsForSteps(any()),
    ).thenAnswer((invocation) async {
      final steps = invocation.positionalArguments.first as Set<SyncStep>;

      return {
        for (final step in steps) step: totalsByStep[step] ?? 0,
      };
    });

    // Stub logging service methods (optional, but good practice)
    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});

    SpySyncController.onSyncAll = null;
  });

  tearDown(() {
    SpySyncController.onSyncAll = null;
  });

  Widget createTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        syncMaintenanceRepositoryProvider.overrideWithValue(
          mockSyncMaintenanceRepository,
        ),
        syncLoggingServiceProvider.overrideWithValue(mockLoggingService),
        syncControllerProvider.overrideWith(SpySyncController.new),
      ],
      child: MaterialApp(
        theme: resolveTestTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: child,
        ), // Use Material to provide context like Directionality
      ),
    );
  }

  testWidgets(
    'SyncModal.show displays confirmation, and calls syncAll on confirm',
    (WidgetTester tester) async {
      // Build a simple widget that can show the dialog
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => SyncModal.show(context),
                child: const Text('Show Sync Modal'),
              );
            },
          ),
        ),
      );

      // Tap the button to show the modal
      await tester.tap(find.text('Show Sync Modal'));
      await tester.pumpAndSettle(); // Wait for animations and dialog to appear

      // Verify the confirmation dialog is shown with the correct message
      expect(find.text(messages.syncEntitiesMessage), findsOneWidget);
      expect(find.text(messages.syncEntitiesConfirm), findsOneWidget);

      // Tap the confirm button
      var syncInvoked = false;
      Set<SyncStep>? capturedSteps;
      SpySyncController.onSyncAll = (steps) {
        syncInvoked = true;
        capturedSteps = steps;
      };

      final confirmButtonFinder = find.widgetWithText(
        DesignSystemButton,
        messages.syncEntitiesConfirm,
      );

      await tester.ensureVisible(confirmButtonFinder);
      final confirmButton = tester.widget<DesignSystemButton>(
        confirmButtonFinder,
      );
      expect(confirmButton.onPressed, isNotNull);
      confirmButton.onPressed!.call();

      await tester.pump();
      await tester.pumpAndSettle();

      expect(syncInvoked, isTrue);
      expect(
        capturedSteps,
        equals(
          {
            SyncStep.measurables,
            SyncStep.labels,
            SyncStep.categories,
            SyncStep.dashboards,
            SyncStep.habits,
            SyncStep.aiSettings,
            SyncStep.backfillAgentEntityClocks,
            SyncStep.backfillAgentLinkClocks,
            SyncStep.agentEntities,
            SyncStep.agentLinks,
          },
        ),
      );

      expect(find.text(messages.syncEntitiesSuccessTitle), findsOneWidget);
      expect(find.text(messages.doneButton.toUpperCase()), findsOneWidget);
      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.text('6 / 6'), findsOneWidget);
      expect(find.text('7 / 7'), findsOneWidget);
      expect(find.text('8 / 8'), findsOneWidget);
      expect(find.text('9 / 9'), findsOneWidget);
      expect(find.text('10 / 10'), findsOneWidget);
    },
  );

  testWidgets(
    'SyncModal lists selectable sync steps on confirmation page',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => SyncModal.show(context),
                child: const Text('Show Sync Modal'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Sync Modal'));
      await tester.pumpAndSettle();

      // Verify the confirmation dialog is shown with the checkboxes for each step
      expect(find.text(messages.syncStepMeasurables), findsOneWidget);
      expect(find.text(messages.syncStepLabels), findsOneWidget);
      expect(find.text(messages.syncStepCategories), findsOneWidget);
      expect(find.text(messages.syncStepDashboards), findsOneWidget);
      expect(find.text(messages.syncStepHabits), findsOneWidget);
      expect(find.text(messages.syncStepAiSettings), findsOneWidget);
    },
  );

  testWidgets('SyncModal disables confirm when no steps selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => SyncModal.show(context),
              child: const Text('Show Sync Modal'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show Sync Modal'));
    await tester.pumpAndSettle();

    final confirmFinder = find.widgetWithText(
      DesignSystemButton,
      messages.syncEntitiesConfirm,
    );

    var confirmButton = tester.widget<DesignSystemButton>(confirmFinder);
    expect(confirmButton.onPressed, isNotNull);

    final checkboxFinder = find.byType(DesignSystemCheckbox);
    final tiles = checkboxFinder.evaluate().toList();
    for (final el in tiles) {
      final tile = el.widget as DesignSystemCheckbox;
      tile.onChanged?.call(false);
      await tester.pump();
    }

    confirmButton = tester.widget<DesignSystemButton>(confirmFinder);
    expect(confirmButton.onPressed, isNull);

    // Re-enable by selecting the first option again.
    // Re-enable by selecting the first option again via callback
    final firstTile = tester.widget<DesignSystemCheckbox>(checkboxFinder.first);
    firstTile.onChanged?.call(true);
    await tester.pump();
    confirmButton = tester.widget<DesignSystemButton>(confirmFinder);
    expect(confirmButton.onPressed, isNotNull);
  });

  group('SyncModal · progress view', () {
    testWidgets(
      'SyncModal widget itself renders nothing (build returns SizedBox.shrink)',
      (tester) async {
        // Even mid-sync, the SyncModal *widget* paints nothing — all UI lives
        // in the modal route opened by SyncModal.show, not in build().
        final testController = TestSyncController(
          const SyncState(isSyncing: true, progress: 50),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncControllerProvider.overrideWith(() => testController),
            ],
            child: MaterialApp(
              theme: resolveTestTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => const SyncModal(),
              ),
            ),
          ),
        );

        expect(find.text('50%'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      },
    );

    testWidgets('progress view reflects controller updates and Done resets', (
      tester,
    ) async {
      const pendingState = SyncState(
        isSyncing: true,
        progress: 50,
        currentStep: SyncStep.categories,
        selectedSteps: {
          SyncStep.measurables,
          SyncStep.categories,
        },
        stepProgress: {
          SyncStep.measurables: StepProgress(processed: 5, total: 5),
          SyncStep.categories: StepProgress(processed: 1, total: 10),
        },
      );

      final controller = _PendingSyncController(pendingState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncControllerProvider.overrideWith(() => controller),
            syncLoggingServiceProvider.overrideWithValue(mockLoggingService),
          ],
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => SyncModal.show(context),
                      child: const Text('Open sync modal'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open sync modal'));
      await tester.pumpAndSettle();

      final confirmButtonFinder = find.widgetWithText(
        DesignSystemButton,
        messages.syncEntitiesConfirm,
      );
      final confirmButton = tester.widget<DesignSystemButton>(
        confirmButtonFinder,
      );
      confirmButton.onPressed?.call();
      await tester.pump();

      // Mid-sync progress: bar, percent, per-step counts and icons.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1 / 10'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(
        find.byIcon(Icons.check_circle_outline),
        findsAtLeastNWidgets(1),
      );

      // Completion: success title + Done button replace the progress bar.
      controller.state = pendingState.copyWith(
        progress: 100,
        currentStep: SyncStep.complete,
        isSyncing: false,
      );
      await tester.pump();

      expect(find.text(messages.syncEntitiesSuccessTitle), findsOneWidget);
      expect(find.text(messages.doneButton.toUpperCase()), findsOneWidget);

      controller.complete();
      await tester.pump();

      // Tapping Done invokes reset() and closes the modal.
      final doneButton = tester.widget<DesignSystemButton>(
        find.widgetWithText(
          DesignSystemButton,
          messages.doneButton.toUpperCase(),
        ),
      );
      doneButton.onPressed?.call();
      await tester.pumpAndSettle();

      expect(controller.resetCalled, isTrue);
    });
  });
}
