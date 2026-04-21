import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/ui/widgets/fetch_all_history_dialog.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockCoordinator extends Mock implements QueuePipelineCoordinator {}

void main() {
  late _MockCoordinator coordinator;

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 1));
  });

  setUp(() {
    coordinator = _MockCoordinator();
  });

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  BootstrapPageInfo pageInfo({required int index, required int total}) =>
      BootstrapPageInfo(
        pageIndex: index,
        totalEventsSoFar: total,
        oldestTimestampSoFar: null,
        serverHasMore: true,
        elapsed: const Duration(milliseconds: 1),
      );

  testWidgets(
    'renders progress updates and final done status',
    (tester) async {
      // Drive three progress updates then resolve to a successful
      // BootstrapResult.
      final progressCompleter = Completer<void>();
      when(
        () => coordinator.collectHistory(
          onProgress: any(named: 'onProgress'),
          cancelSignal: any(named: 'cancelSignal'),
          overallTimeout: any(named: 'overallTimeout'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress]
                as void Function(BootstrapPageInfo)?;
        onProgress?.call(pageInfo(index: 0, total: 50));
        onProgress?.call(pageInfo(index: 1, total: 120));
        progressCompleter.complete();
        return const BootstrapResult(
          totalPages: 2,
          totalEvents: 120,
          oldestTimestampReached: 1000,
          stopReason: BootstrapStopReason.serverExhausted,
        );
      });

      await tester.pumpWidget(
        wrap(FetchAllHistoryDialog(coordinator: coordinator)),
      );
      await progressCompleter.future;
      await tester.pumpAndSettle();

      // Match the full rendered done message instead of bare "2" /
      // "120" substrings — the digit 2 appears inside 120, so
      // `findsWidgets` passed even when the page count was wrong.
      expect(
        find.text('Fetched 120 events across 2 pages.'),
        findsOneWidget,
      );
      // "Close" button appears once the run ends.
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    },
  );

  testWidgets(
    'cancel button completes the cancel signal passed to collectHistory',
    (tester) async {
      final capturedCancel = Completer<Future<void>?>();
      when(
        () => coordinator.collectHistory(
          onProgress: any(named: 'onProgress'),
          cancelSignal: any(named: 'cancelSignal'),
          overallTimeout: any(named: 'overallTimeout'),
        ),
      ).thenAnswer((invocation) async {
        capturedCancel.complete(
          invocation.namedArguments[#cancelSignal] as Future<void>?,
        );
        // Wait until the cancel signal fires, then return a cancelled
        // BootstrapResult.
        final cancelFuture =
            invocation.namedArguments[#cancelSignal] as Future<void>?;
        await cancelFuture;
        return const BootstrapResult(
          totalPages: 0,
          totalEvents: 0,
          oldestTimestampReached: null,
          stopReason: BootstrapStopReason.sinkCancelled,
        );
      });

      await tester.pumpWidget(
        wrap(FetchAllHistoryDialog(coordinator: coordinator)),
      );
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));

      final cancelSignal = await capturedCancel.future;
      expect(cancelSignal, isNotNull);
      // The cancel signal must resolve — the widget's tap handler
      // completes the underlying completer.
      await expectLater(cancelSignal, completes);

      await tester.pumpAndSettle();
      expect(find.text('Close'), findsOneWidget);
    },
  );

  testWidgets(
    'renders error status when collectHistory throws',
    (tester) async {
      when(
        () => coordinator.collectHistory(
          onProgress: any(named: 'onProgress'),
          cancelSignal: any(named: 'cancelSignal'),
          overallTimeout: any(named: 'overallTimeout'),
        ),
      ).thenThrow(StateError('no current room'));

      await tester.pumpWidget(
        wrap(FetchAllHistoryDialog(coordinator: coordinator)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('no current room'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    },
  );

  testWidgets(
    'renders initial loading status before any progress arrives',
    (tester) async {
      final completer = Completer<BootstrapResult>();
      when(
        () => coordinator.collectHistory(
          onProgress: any(named: 'onProgress'),
          cancelSignal: any(named: 'cancelSignal'),
          overallTimeout: any(named: 'overallTimeout'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        wrap(FetchAllHistoryDialog(coordinator: coordinator)),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      completer.complete(
        const BootstrapResult(
          totalPages: 1,
          totalEvents: 0,
          oldestTimestampReached: null,
          stopReason: BootstrapStopReason.serverExhausted,
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'boundaryReached stopReason renders the done message',
    (tester) async {
      when(
        () => coordinator.collectHistory(
          onProgress: any(named: 'onProgress'),
          cancelSignal: any(named: 'cancelSignal'),
          overallTimeout: any(named: 'overallTimeout'),
        ),
      ).thenAnswer(
        (_) async => const BootstrapResult(
          totalPages: 3,
          totalEvents: 42,
          oldestTimestampReached: 500,
          stopReason: BootstrapStopReason.boundaryReached,
        ),
      );

      await tester.pumpWidget(
        wrap(FetchAllHistoryDialog(coordinator: coordinator)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Fetched 42 events across 3 pages.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'dispose mid-run completes cancel signal without crashing',
    (tester) async {
      final cancelFuture = Completer<Future<void>?>();
      when(
        () => coordinator.collectHistory(
          onProgress: any(named: 'onProgress'),
          cancelSignal: any(named: 'cancelSignal'),
          overallTimeout: any(named: 'overallTimeout'),
        ),
      ).thenAnswer((invocation) async {
        final signal =
            invocation.namedArguments[#cancelSignal] as Future<void>?;
        cancelFuture.complete(signal);
        await signal;
        return const BootstrapResult(
          totalPages: 0,
          totalEvents: 0,
          oldestTimestampReached: null,
          stopReason: BootstrapStopReason.sinkCancelled,
        );
      });

      await tester.pumpWidget(
        wrap(FetchAllHistoryDialog(coordinator: coordinator)),
      );
      await tester.pump();

      // Unmount the dialog mid-run.
      await tester.pumpWidget(wrap(const SizedBox()));

      final signal = await cancelFuture.future;
      expect(signal, isNotNull);
      await expectLater(signal, completes);
    },
  );

  testWidgets(
    'error stopReason with a concrete exception renders the '
    '"Fetch stopped: {reason}" string — covers the reason-present '
    'branch of the error status switch',
    (tester) async {
      when(
        () => coordinator.collectHistory(
          onProgress: any(named: 'onProgress'),
          cancelSignal: any(named: 'cancelSignal'),
          overallTimeout: any(named: 'overallTimeout'),
        ),
      ).thenThrow(StateError('boom'));

      await tester.pumpWidget(
        wrap(FetchAllHistoryDialog(coordinator: coordinator)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Fetch stopped'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    },
  );

  testWidgets(
    'stopReason=error with _error=null falls back to the localized '
    '"Fetch stopped unexpectedly" string — covers the nil-error '
    'branch of the error status switch',
    (tester) async {
      // Return a BootstrapResult with stopReason=error so the switch
      // enters the error branch with a non-null _result but _error
      // still null (no throw from collectHistory itself).
      when(
        () => coordinator.collectHistory(
          onProgress: any(named: 'onProgress'),
          cancelSignal: any(named: 'cancelSignal'),
          overallTimeout: any(named: 'overallTimeout'),
        ),
      ).thenAnswer(
        (_) async => const BootstrapResult(
          totalPages: 0,
          totalEvents: 0,
          oldestTimestampReached: null,
          stopReason: BootstrapStopReason.error,
        ),
      );

      await tester.pumpWidget(
        wrap(FetchAllHistoryDialog(coordinator: coordinator)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Fetch stopped unexpectedly.'),
        findsOneWidget,
      );
    },
  );
}
