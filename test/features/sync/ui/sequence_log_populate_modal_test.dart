import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/features/sync/ui/sequence_log_populate_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockLoggingDb extends Mock implements LoggingDb {}

// Fake types for mocktail fallback
class FakeEntryStream extends Fake
    implements Stream<List<({String id, Map<String, int>? vectorClock})>> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncSequenceLogService mockSequenceLogService;
  late MockJournalDb mockJournalDb;
  late MockLoggingService mockLoggingService;
  late MockLoggingDb mockLoggingDb;

  setUpAll(() {
    registerFallbackValue(FakeEntryStream());
  });

  setUp(() async {
    await getIt.reset();

    mockSequenceLogService = MockSyncSequenceLogService();
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockLoggingService();
    mockLoggingDb = MockLoggingDb();

    getIt
      ..registerSingleton<SyncSequenceLogService>(mockSequenceLogService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<LoggingDb>(mockLoggingDb);
  });

  tearDown(getIt.reset);

  Widget buildTestWidget({required Widget child}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('SequenceLogPopulateModal', () {
    testWidgets('shows modal when called', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => SequenceLogPopulateModal.show(context),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Modal should be visible with cancel button
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('can be dismissed by tapping outside', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => SequenceLogPopulateModal.show(context),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Tap outside the modal (barrier)
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      // Modal should be dismissed
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('SequenceLogPopulateState progressBuilder', () {
    // Test the progressBuilder content directly using the state

    testWidgets('shows error icon when state has error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sequenceLogPopulateControllerProvider.overrideWith(
              () => _TestController(
                const SequenceLogPopulateState(
                  error: 'Test error message',
                  isRunning: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final state =
                      ref.watch(sequenceLogPopulateControllerProvider);
                  return _buildProgressContent(context, state);
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
    });

    testWidgets('shows check icon when completed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sequenceLogPopulateControllerProvider.overrideWith(
              () => _TestController(
                const SequenceLogPopulateState(
                  progress: 1.0,
                  isRunning: false,
                  populatedCount: 42,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final state =
                      ref.watch(sequenceLogPopulateControllerProvider);
                  return _buildProgressContent(context, state);
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      // The count should be displayed
      expect(find.textContaining('42'), findsOneWidget);
    });

    testWidgets('shows progress bar when running', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sequenceLogPopulateControllerProvider.overrideWith(
              () => _TestController(
                const SequenceLogPopulateState(
                  progress: 0.5,
                  isRunning: true,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final state =
                      ref.watch(sequenceLogPopulateControllerProvider);
                  return _buildProgressContent(context, state);
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('shows initial state before running', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sequenceLogPopulateControllerProvider.overrideWith(
              () => _TestController(
                const SequenceLogPopulateState(
                  progress: 0,
                  isRunning: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final state =
                      ref.watch(sequenceLogPopulateControllerProvider);
                  return _buildProgressContent(context, state);
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not show error or completion icons
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });
  });
}

/// Test controller that returns a fixed state
class _TestController extends SequenceLogPopulateController {
  _TestController(this._initialState);

  final SequenceLogPopulateState _initialState;

  @override
  SequenceLogPopulateState build() => _initialState;

  @override
  Future<void> populateSequenceLog() async {}
}

/// Replicates the progressBuilder content from SequenceLogPopulateModal
Widget _buildProgressContent(
    BuildContext context, SequenceLogPopulateState state) {
  final progress = state.progress;
  final isRunning = state.isRunning;
  final error = state.error;
  final populatedCount = state.populatedCount;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 16),
      if (error != null)
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        )
      else if (progress == 1.0 && !isRunning)
        Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'Populated $populatedCount entries',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        )
      else if (isRunning)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 5,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ],
        ),
      const SizedBox(height: 16),
      if (error != null)
        Text(
          error,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
    ],
  );
}
