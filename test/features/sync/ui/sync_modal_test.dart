import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/get_it.dart';
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

void main() {
  late MockSyncMaintenanceRepository mockSyncMaintenanceRepository;
  late MockLoggingService mockLoggingService;
  late AppLocalizations messages;

  setUpAll(() {
    // Register a fallback value for StackTrace if it's used by the mock
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockSyncMaintenanceRepository = MockSyncMaintenanceRepository();
    mockLoggingService = MockLoggingService();
    messages = AppLocalizationsEn(); // Using English for tests

    // Register mock LoggingService with GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Stub all repository methods to return successful futures
    when(
      () => mockSyncMaintenanceRepository.syncTags(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockSyncMaintenanceRepository.syncMeasurables(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockSyncMaintenanceRepository.syncCategories(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockSyncMaintenanceRepository.syncDashboards(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockSyncMaintenanceRepository.syncHabits(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockSyncMaintenanceRepository.syncAiSettings(
        onProgress: any(named: 'onProgress'),
        onDetailedProgress: any(named: 'onDetailedProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());

    // Stub logging service methods (optional, but good practice)
    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenReturn(null); // Or some other appropriate response
  });

  tearDown(() {
    // Unregister LoggingService after each test to ensure a clean state
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  Widget createTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        syncMaintenanceRepositoryProvider
            .overrideWithValue(mockSyncMaintenanceRepository),
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

    // Re-apply select all to ensure the confirm button is enabled
    await tester.pump();

    // Tap the confirm button
    await tester.ensureVisible(find.text(messages.syncEntitiesConfirm));
    await tester.tap(
      find.text(messages.syncEntitiesConfirm),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
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
    final totalCheckboxes = checkboxFinder.evaluate().length;
    for (var i = 0; i < totalCheckboxes; i++) {
      await tester.tap(checkboxFinder.at(i));
      await tester.pump();
    }

    confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
    expect(confirmButton.onPressed, isNull);

    // Re-enable by selecting the first option again.
    await tester.tap(checkboxFinder.first);
    await tester.pump();
    confirmButton = tester.widget<LottiPrimaryButton>(confirmFinder);
    expect(confirmButton.onPressed, isNotNull);
  });
}
