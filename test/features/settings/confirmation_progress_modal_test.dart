import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/settings/ui/confirmation_progress_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockLoggingDb extends Mock implements LoggingDb {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late MockLoggingDb mockLoggingDb;

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockLoggingDb = MockLoggingDb();

    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<LoggingDb>(mockLoggingDb);
  });

  tearDown(getIt.reset);

  group('ConfirmationProgressModal', () {
    testWidgets('shows confirmation page with correct content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfirmationProgressModal.show(
                        context: context,
                        message: 'Are you sure you want to delete this?',
                        confirmLabel: 'Delete',
                        progressBuilder: (context) => const Text('Progress...'),
                        operation: () async {
                          await Future<void>.delayed(
                              const Duration(milliseconds: 100));
                        },
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify confirmation page content
      expect(
          find.text('Are you sure you want to delete this?'), findsOneWidget);
      expect(find.text('DELETE'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('shows non-destructive modal without warning icon',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfirmationProgressModal.show(
                        context: context,
                        message: 'Continue with this action?',
                        confirmLabel: 'Continue',
                        progressBuilder: (context) => const Text('Progress...'),
                        operation: () async {
                          await Future<void>.delayed(
                              const Duration(milliseconds: 100));
                        },
                        isDestructive: false,
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify no warning icon for non-destructive operations
      expect(find.text('Continue with this action?'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('cancels operation when cancel button is pressed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfirmationProgressModal.show(
                        context: context,
                        message: 'Test message',
                        confirmLabel: 'Confirm',
                        progressBuilder: (context) => const Text('Progress...'),
                        operation: () async {},
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Instead of using context.messages.cancelButton, use 'Cancel' directly if that's the label in the widget.
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify modal was dismissed
      expect(find.text('Test message'), findsNothing);
    });

    testWidgets('cancels operation when tapping outside modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfirmationProgressModal.show(
                        context: context,
                        message: 'Test message',
                        confirmLabel: 'Confirm',
                        progressBuilder: (context) => const Text('Progress...'),
                        operation: () async {},
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Tap outside the modal (barrier)
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      // Verify modal was dismissed
      expect(find.text('Test message'), findsNothing);
    });

    testWidgets('confirms operation and shows progress page', (tester) async {
      var operationCalled = false;
      var confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      confirmed = await ConfirmationProgressModal.show(
                        context: context,
                        message: 'Test message',
                        confirmLabel: 'Confirm',
                        progressBuilder: (context) => const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Processing...'),
                          ],
                        ),
                        operation: () async {
                          operationCalled = true;
                          await Future<void>.delayed(
                              const Duration(milliseconds: 200));
                        },
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Tap confirm button
      await tester.tap(find.text('CONFIRM'));
      await tester.pump();

      // Verify progress page is shown
      expect(find.text('Processing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // No close button since hasTopBarLayer is false

      // Wait for operation to complete
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // Verify operation was called and confirmed
      expect(operationCalled, isTrue);
      expect(confirmed, isTrue);
    });

    testWidgets('uses correct styling for destructive operations',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfirmationProgressModal.show(
                        context: context,
                        message: 'Delete this item?',
                        confirmLabel: 'Delete',
                        progressBuilder: (context) => const Text('Progress...'),
                        operation: () async {
                          await Future<void>.delayed(
                              const Duration(milliseconds: 100));
                        },
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Find the confirm button and verify it uses error color
      final confirmButtonFinder = find.ancestor(
        of: find.text('DELETE'),
        matching: find.byType(LottiPrimaryButton),
      );
      final confirmButton =
          tester.widget<LottiPrimaryButton>(confirmButtonFinder);
      Theme.of(tester.element(confirmButtonFinder));

      // Verify the button uses error styling for destructive operations
      expect(
        confirmButton.isDestructive,
        isTrue,
      );
    });

    testWidgets('uses correct styling for non-destructive operations',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfirmationProgressModal.show(
                        context: context,
                        message: 'Continue with this action?',
                        confirmLabel: 'Continue',
                        progressBuilder: (context) => const Text('Progress...'),
                        operation: () async {
                          await Future<void>.delayed(
                              const Duration(milliseconds: 100));
                        },
                        isDestructive: false,
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Find the confirm button and verify it uses primary color
      final confirmButtonFinder = find.ancestor(
        of: find.text('CONTINUE'),
        matching: find.byType(LottiPrimaryButton),
      );
      final confirmButton =
          tester.widget<LottiPrimaryButton>(confirmButtonFinder);
      Theme.of(tester.element(confirmButtonFinder));

      // Verify the button uses primary styling for non-destructive operations
      expect(
        confirmButton.isDestructive,
        isFalse,
      );
    });

    testWidgets('handles operation exceptions gracefully', (tester) async {
      var confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      confirmed = await ConfirmationProgressModal.show(
                        context: context,
                        message: 'Test message',
                        confirmLabel: 'Confirm',
                        progressBuilder: (context) => const Text('Progress...'),
                        operation: () async {
                          throw Exception('Test exception');
                        },
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Tap confirm button
      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();

      // Verify modal still completes (exception is handled)
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Should still return true even if operation throws
      expect(confirmed, isTrue);
    });

    testWidgets('modal is dismissible with barrier tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 600)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfirmationProgressModal.show(
                        context: context,
                        message: 'Test message',
                        confirmLabel: 'Confirm',
                        progressBuilder: (context) => const Text('Progress...'),
                        operation: () async {},
                      );
                    },
                    child: const Text('Show Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Try to tap outside the modal (barrier)
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      // Verify modal was dismissed
      expect(find.text('Test message'), findsNothing);
    });
  });
}
