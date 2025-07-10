import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/logging_service.dart';
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
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockSyncMaintenanceRepository.syncMeasurables(
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockSyncMaintenanceRepository.syncCategories(
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockSyncMaintenanceRepository.syncDashboards(
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockSyncMaintenanceRepository.syncHabits(
        onProgress: any(named: 'onProgress'),
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

    // Tap the confirm button
    await tester.tap(find.text(messages.syncEntitiesConfirm));
    await tester
        .pumpAndSettle(); // Wait for dialog to close and async operations

    // Verify that all sync methods on the repository were called
    verify(
      () => mockSyncMaintenanceRepository.syncTags(
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
    verify(
      () => mockSyncMaintenanceRepository.syncMeasurables(
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
    verify(
      () => mockSyncMaintenanceRepository.syncCategories(
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
    verify(
      () => mockSyncMaintenanceRepository.syncDashboards(
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
    verify(
      () => mockSyncMaintenanceRepository.syncHabits(
        onProgress: any(named: 'onProgress'),
      ),
    ).called(1);
  });

  testWidgets(
    'SyncModal shows categories step in sync indicator',
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
      await tester.pumpAndSettle();

      // Verify the confirmation dialog is shown with the correct message
      expect(find.text(messages.syncEntitiesMessage), findsOneWidget);
      expect(find.text(messages.syncEntitiesConfirm), findsOneWidget);

      // Tap the confirm button to proceed to progress page
      await tester.tap(find.text(messages.syncEntitiesConfirm));
      await tester.pump();

      // Now check for the categories step in the progress page
      expect(find.text(messages.syncStepCategories), findsOneWidget);

      // Verify that the sync operation for categories was called
      verify(
        () => mockSyncMaintenanceRepository.syncCategories(
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    },
  );
}
