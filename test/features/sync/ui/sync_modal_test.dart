import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/state/sync_maintenance_controller.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:mocktail/mocktail.dart';

// Mock for SyncMaintenanceRepository
class MockSyncMaintenanceRepository extends Mock
    implements SyncMaintenanceRepository {}

// Mock for LoggingService
class MockLoggingService extends Mock implements LoggingService {}

class SpySyncController extends SyncMaintenanceController {
  SpySyncController();

  static void Function(Set<SyncStep> steps)? onSyncAll;

  @override
  Future<void> syncAll({required Set<SyncStep> selectedSteps}) {
    onSyncAll?.call(selectedSteps);
    return super.syncAll(selectedSteps: selectedSteps);
  }
}

void main() {
  late MockSyncMaintenanceRepository mockSyncMaintenanceRepository;
  late MockLoggingService mockLoggingService;
  late AppLocalizations messages;

  setUpAll(() {
    // Register a fallback value for StackTrace if it's used by the mock
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(<SyncStep>{});
  });

  setUp(() {
    mockSyncMaintenanceRepository = MockSyncMaintenanceRepository();
    mockLoggingService = MockLoggingService();
    messages = AppLocalizationsEn(); // Using English for tests

    const totalsByStep = <SyncStep, int>{
      SyncStep.tags: 4,
      SyncStep.measurables: 5,
      SyncStep.labels: 6,
      SyncStep.categories: 7,
      SyncStep.dashboards: 8,
      SyncStep.habits: 9,
      SyncStep.aiSettings: 10,
    };

    Future<void> simulateStep(
      SyncStep step,
      Invocation invocation,
    ) async {
      final onProgress = invocation.namedArguments[const Symbol('onProgress')]
          as void Function(double)?;
      final onDetailedProgress =
          invocation.namedArguments[const Symbol('onDetailedProgress')] as void
              Function(int processed, int total)?;
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
      () => mockSyncMaintenanceRepository.syncTags(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((invocation) => simulateStep(SyncStep.tags, invocation));
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
      () => mockSyncMaintenanceRepository.fetchTotalsForSteps(any()),
    ).thenAnswer((invocation) async {
      final steps = invocation.positionalArguments.first as Set<SyncStep>;

      return {
        for (final step in steps) step: totalsByStep[step] ?? 0,
      };
    });

    // Stub logging service methods (optional, but good practice)
    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenReturn(null); // Or some other appropriate response

    SpySyncController.onSyncAll = null;
  });

  tearDown(() {
    SpySyncController.onSyncAll = null;
  });

  Widget createTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        syncMaintenanceRepositoryProvider
            .overrideWithValue(mockSyncMaintenanceRepository),
        syncLoggingServiceProvider.overrideWithValue(mockLoggingService),
        syncControllerProvider.overrideWith(SpySyncController.new),
      ],
      child: MaterialApp(
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
      LottiPrimaryButton,
      messages.syncEntitiesConfirm,
    );

    await tester.ensureVisible(confirmButtonFinder);
    final confirmButton =
        tester.widget<LottiPrimaryButton>(confirmButtonFinder);
    expect(confirmButton.onPressed, isNotNull);
    confirmButton.onPressed!.call();

    await tester.pump();
    await tester.pumpAndSettle();

    expect(syncInvoked, isTrue);
    expect(
      capturedSteps,
      equals(
        {
          SyncStep.tags,
          SyncStep.measurables,
          SyncStep.labels,
          SyncStep.categories,
          SyncStep.dashboards,
          SyncStep.habits,
          SyncStep.aiSettings,
        },
      ),
    );

    expect(find.text(messages.syncEntitiesSuccessTitle), findsOneWidget);
    expect(find.text(messages.doneButton.toUpperCase()), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('6 / 6'), findsOneWidget);
    expect(find.text('7 / 7'), findsOneWidget);
    expect(find.text('8 / 8'), findsOneWidget);
    expect(find.text('9 / 9'), findsOneWidget);
    expect(find.text('10 / 10'), findsOneWidget);
  });

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
      expect(find.text(messages.syncStepTags), findsOneWidget);
      expect(find.text(messages.syncStepMeasurables), findsOneWidget);
      expect(find.text(messages.syncStepLabels), findsOneWidget);
      expect(find.text(messages.syncStepCategories), findsOneWidget);
      expect(find.text(messages.syncStepDashboards), findsOneWidget);
      expect(find.text(messages.syncStepHabits), findsOneWidget);
      expect(find.text(messages.syncStepAiSettings), findsOneWidget);
    },
  );

  testWidgets('SyncModal disables confirm when no steps selected',
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

    final confirmFinder = find.widgetWithText(
      LottiPrimaryButton,
      messages.syncEntitiesConfirm.toUpperCase(),
    );

    var confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
    expect(confirmButton.onPressed, isNotNull);

    final checkboxFinder = find.byType(CheckboxListTile);
    final tiles = checkboxFinder.evaluate().toList();
    for (final el in tiles) {
      final tile = el.widget as CheckboxListTile;
      tile.onChanged?.call(false);
      await tester.pump();
    }

    confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
    expect(confirmButton.onPressed, isNull);

    // Re-enable by selecting the first option again.
    // Re-enable by selecting the first option again via callback
    final firstTile = tester.widget<CheckboxListTile>(checkboxFinder.first);
    firstTile.onChanged?.call(true);
    await tester.pump();
    confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
    expect(confirmButton.onPressed, isNotNull);
  });
}
