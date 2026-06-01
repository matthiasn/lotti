import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/features/sync/ui/sequence_log_populate_modal.dart';
import 'package:lotti/features/sync/ui/sequence_log_populate_progress.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Test double for the populate controller. Records whether the modal's
/// `operation` callback delegated to [populateSequenceLog] and lets a test
/// push arbitrary state so the `progressBuilder` Consumer can be observed.
class _FakePopulateController extends SequenceLogPopulateController {
  int populateCalls = 0;

  /// Held open so the modal does not auto-pop the progress page (it pops in the
  /// `finally` of the operation when `closeOnComplete` is true). Tests complete
  /// this once they have asserted on the visible progress page.
  final Completer<void> operationGate = Completer<void>();

  @override
  Future<void> populateSequenceLog() async {
    populateCalls++;
    // Mimic the running phase so the progress page renders the running UI.
    state = state.copyWith(
      isRunning: true,
      progress: 0.5,
      phase: SequenceLogPopulatePhase.populatingJournal,
    );
    await operationGate.future;
  }

  /// Pushes a terminal "done" state from the test, exercising the Consumer's
  /// rebuild path on the progress page.
  void completeWithCounts({required int journal, required int links}) {
    state = state.copyWith(
      isRunning: false,
      progress: 1,
      phase: SequenceLogPopulatePhase.done,
      populatedCount: journal,
      populatedLinksCount: links,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncSequenceLogService mockSequenceLogService;
  late MockJournalDb mockJournalDb;
  late MockDomainLogger mockLoggingService;

  setUp(() async {
    await getIt.reset();

    mockSequenceLogService = MockSyncSequenceLogService();
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockDomainLogger();

    getIt
      ..registerSingleton<SyncSequenceLogService>(mockSequenceLogService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<DomainLogger>(mockLoggingService);

    when(
      () => mockLoggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(getIt.reset);

  Widget buildTestWidget({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
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

  Widget showTrigger() {
    return Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () => SequenceLogPopulateModal.show(context),
          child: const Text('Show Modal'),
        );
      },
    );
  }

  /// Opens the modal and taps its confirm button. The button sits at the bottom
  /// of the modal sheet, so it is scrolled into view before tapping.
  Future<void> openAndConfirm(WidgetTester tester) async {
    await tester.tap(find.text('Show Modal'));
    await tester.pumpAndSettle();

    final confirmButton = find.byType(LottiPrimaryButton);
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
  }

  group('SequenceLogPopulateModal', () {
    testWidgets('shows modal with confirmation page', (tester) async {
      await tester.pumpWidget(buildTestWidget(child: showTrigger()));

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Confirmation page visible
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('dismisses on cancel', (tester) async {
      await tester.pumpWidget(buildTestWidget(child: showTrigger()));

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Tap Cancel button (warnIfMissed: false because modal barrier intercepts
      // the hit test but the tap still propagates correctly).
      await tester.tap(find.text('Cancel'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('shows the localized confirmation message', (tester) async {
      await tester.pumpWidget(buildTestWidget(child: showTrigger()));

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('scan all journal entries'),
        findsOneWidget,
      );
    });

    testWidgets(
      'confirm delegates to controller.populateSequenceLog and renders '
      'the progress page Consumer',
      (tester) async {
        final fakeController = _FakePopulateController();

        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              sequenceLogPopulateControllerProvider.overrideWith(
                () => fakeController,
              ),
            ],
            child: showTrigger(),
          ),
        );

        // Tapping confirm runs the modal's `operation` callback (lines 18-20),
        // which must delegate to the controller.
        await openAndConfirm(tester);

        // The operation callback delegated exactly once to the controller.
        expect(fakeController.populateCalls, 1);

        // The progress page (lines 23-25) renders a Consumer that watches the
        // controller and builds SequenceLogPopulateProgress with its state.
        // The fake set isRunning + 50% progress.
        expect(find.byType(SequenceLogPopulateProgress), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);

        final progress = tester.widget<SequenceLogPopulateProgress>(
          find.byType(SequenceLogPopulateProgress),
        );
        expect(progress.state.isRunning, isTrue);
        expect(progress.state.progress, 0.5);

        // Let the operation finish so the modal closes without leaking timers.
        fakeController.operationGate.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'progress page Consumer rebuilds when controller state changes',
      (tester) async {
        final fakeController = _FakePopulateController();

        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              sequenceLogPopulateControllerProvider.overrideWith(
                () => fakeController,
              ),
            ],
            child: showTrigger(),
          ),
        );

        await openAndConfirm(tester);

        expect(find.text('50%'), findsOneWidget);

        // Push a terminal state externally; the watched Consumer must rebuild
        // and the progress widget must reflect the new state (completion UI).
        fakeController.completeWithCounts(journal: 7, links: 3);
        await tester.pump();

        final progress = tester.widget<SequenceLogPopulateProgress>(
          find.byType(SequenceLogPopulateProgress),
        );
        expect(progress.state.phase, SequenceLogPopulatePhase.done);
        expect(progress.state.populatedCount, 7);
        expect(progress.state.populatedLinksCount, 3);

        // Completion UI: check icon + total (7 + 3 = 10).
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.textContaining('10'), findsOneWidget);

        // Let the operation finish so the modal closes without leaking timers.
        fakeController.operationGate.complete();
        await tester.pumpAndSettle();
      },
    );
  });

  group('SequenceLogPopulateState', () {
    test('default values', () {
      const state = SequenceLogPopulateState();
      expect(state.progress, 0);
      expect(state.isRunning, false);
      expect(state.populatedCount, isNull);
      expect(state.totalCount, isNull);
      expect(state.error, isNull);
    });

    test('copyWith preserves values when not overridden', () {
      const state = SequenceLogPopulateState(
        progress: 0.5,
        isRunning: true,
        populatedCount: 100,
        totalCount: 200,
        error: 'error',
      );
      final copied = state.copyWith();
      expect(copied.progress, 0.5);
      expect(copied.isRunning, true);
      expect(copied.populatedCount, 100);
      expect(copied.totalCount, 200);
      expect(copied.error, 'error');
    });

    test('copyWith overrides specified values', () {
      const state = SequenceLogPopulateState();
      final copied = state.copyWith(
        progress: 0.75,
        isRunning: true,
        populatedCount: 50,
        totalCount: 100,
        error: 'new error',
      );
      expect(copied.progress, 0.75);
      expect(copied.isRunning, true);
      expect(copied.populatedCount, 50);
      expect(copied.totalCount, 100);
      expect(copied.error, 'new error');
    });

    test('copyWith clearError removes error', () {
      const state = SequenceLogPopulateState(error: 'error');
      final copied = state.copyWith(clearError: true);
      expect(copied.error, isNull);
    });

    test('copyWith clearCount removes counts', () {
      const state = SequenceLogPopulateState(
        populatedCount: 100,
        totalCount: 200,
      );
      final copied = state.copyWith(clearCount: true);
      expect(copied.populatedCount, isNull);
      expect(copied.totalCount, isNull);
    });

    test('copyWith clearError takes precedence over new error', () {
      const state = SequenceLogPopulateState(error: 'old');
      final copied = state.copyWith(clearError: true, error: 'new');
      expect(copied.error, isNull);
    });

    test('copyWith clearCount takes precedence over new counts', () {
      const state = SequenceLogPopulateState(
        populatedCount: 10,
        totalCount: 20,
      );
      final copied = state.copyWith(
        clearCount: true,
        populatedCount: 30,
        totalCount: 40,
      );
      expect(copied.populatedCount, isNull);
      expect(copied.totalCount, isNull);
    });
  });
}
