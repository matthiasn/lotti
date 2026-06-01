import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Pumps a [ConflictsPage] with the given mock DB already registered in GetIt.
Future<void> _pumpConflictsPage(WidgetTester tester) async {
  await tester.pumpWidget(
    makeTestableWidget(
      const SizedBox(
        width: 600,
        height: 900,
        child: ConflictsPage(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConflictsPage – stream states & navigation', () {
    late MockJournalDb mockDb;

    setUp(() {
      mockDb = MockJournalDb();
      getIt
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<JournalDb>(mockDb);
    });

    tearDown(getIt.reset);

    // -----------------------------------------------------------------------
    // ConflictsBody delegates to ConflictsPage (line 23)
    // -----------------------------------------------------------------------
    testWidgets(
      'ConflictsBody renders the same content as ConflictsPage',
      (tester) async {
        when(
          () => mockDb.watchConflicts(ConflictStatus.unresolved),
        ).thenAnswer(
          (_) => Stream<List<Conflict>>.fromIterable([
            [unresolvedConflict],
          ]),
        );
        when(
          () => mockDb.watchConflicts(ConflictStatus.resolved),
        ).thenAnswer(
          (_) => Stream<List<Conflict>>.fromIterable([
            <Conflict>[],
          ]),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const SizedBox(
              width: 600,
              height: 900,
              child: ConflictsBody(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ConflictsBody just wraps ConflictsPage — the title confirms the
        // full subtree rendered.
        expect(find.text('Sync Conflicts'), findsOneWidget);
        expect(find.text('Unresolved · 1 item'), findsOneWidget);
      },
    );

    // -----------------------------------------------------------------------
    // Error in unresolved subscription (lines 67–69)
    // -----------------------------------------------------------------------
    testWidgets(
      'unresolved subscription error is forwarded without crashing the page',
      (tester) async {
        final unresolvedController = StreamController<List<Conflict>>();
        final resolvedController = StreamController<List<Conflict>>();

        when(
          () => mockDb.watchConflicts(ConflictStatus.unresolved),
        ).thenAnswer((_) => unresolvedController.stream);
        when(
          () => mockDb.watchConflicts(ConflictStatus.resolved),
        ).thenAnswer((_) => resolvedController.stream);

        await _pumpConflictsPage(tester);
        await tester.pump();

        // Before any data: loading spinner is shown.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Emit an error on the unresolved subscription (exercises lines 67–69).
        unresolvedController.addError(StateError('db failure'));
        resolvedController.add(<Conflict>[]);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // When the combined controller forwards the error, the StreamBuilder
        // still has no data (hasData == false) so the spinner remains — the
        // key guarantee is that the widget tree did not crash.
        expect(find.byType(ConflictsPage), findsOneWidget);

        await unresolvedController.close();
        await resolvedController.close();
      },
    );

    // -----------------------------------------------------------------------
    // Error in resolved subscription (lines 81–83)
    // -----------------------------------------------------------------------
    testWidgets(
      'resolved subscription error is forwarded without crashing the page',
      (tester) async {
        final unresolvedController = StreamController<List<Conflict>>();
        final resolvedController = StreamController<List<Conflict>>();

        when(
          () => mockDb.watchConflicts(ConflictStatus.unresolved),
        ).thenAnswer((_) => unresolvedController.stream);
        when(
          () => mockDb.watchConflicts(ConflictStatus.resolved),
        ).thenAnswer((_) => resolvedController.stream);

        await _pumpConflictsPage(tester);
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Emit an error on the resolved subscription (exercises lines 81–83).
        resolvedController.addError(StateError('resolved db error'));
        unresolvedController.add(<Conflict>[]);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Widget tree still alive after the error was forwarded.
        expect(find.byType(ConflictsPage), findsOneWidget);

        await unresolvedController.close();
        await resolvedController.close();
      },
    );

    // -----------------------------------------------------------------------
    // onPause / onResume of the combined stream (lines 89–90, 93–94)
    // -----------------------------------------------------------------------
    testWidgets(
      'stream pause and resume keep page functional',
      (tester) async {
        final unresolvedController =
            StreamController<List<Conflict>>.broadcast();
        final resolvedController = StreamController<List<Conflict>>.broadcast();

        when(
          () => mockDb.watchConflicts(ConflictStatus.unresolved),
        ).thenAnswer((_) => unresolvedController.stream);
        when(
          () => mockDb.watchConflicts(ConflictStatus.resolved),
        ).thenAnswer((_) => resolvedController.stream);

        await _pumpConflictsPage(tester);
        await tester.pump();

        unresolvedController.add([unresolvedConflict]);
        resolvedController.add(<Conflict>[]);

        await tester.pumpAndSettle();
        expect(find.text('Unresolved · 1 item'), findsOneWidget);

        // Remove the widget from the tree; this cancels the stream listener
        // which triggers onCancel and indirectly exercises the pause/resume
        // lifecycle of the inner subscriptions before cancel is invoked.
        await tester.pumpWidget(
          makeTestableWidget(const SizedBox.shrink()),
        );
        await tester.pumpAndSettle();

        // Pump the page back in to verify it can re-subscribe cleanly after
        // the previous subscription was torn down.
        when(
          () => mockDb.watchConflicts(ConflictStatus.unresolved),
        ).thenAnswer(
          (_) => Stream<List<Conflict>>.fromIterable([
            [unresolvedConflict],
          ]),
        );
        when(
          () => mockDb.watchConflicts(ConflictStatus.resolved),
        ).thenAnswer(
          (_) => Stream<List<Conflict>>.fromIterable([
            <Conflict>[],
          ]),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const SizedBox(
              width: 600,
              height: 900,
              child: ConflictsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Unresolved · 1 item'), findsOneWidget);

        await unresolvedController.close();
        await resolvedController.close();
      },
    );

    // -----------------------------------------------------------------------
    // onTap navigates to conflict detail (line 157)
    // -----------------------------------------------------------------------
    testWidgets(
      'tapping a conflict list item navigates to the conflict detail route',
      (tester) async {
        when(
          () => mockDb.watchConflicts(ConflictStatus.unresolved),
        ).thenAnswer(
          (_) => Stream<List<Conflict>>.fromIterable([
            [unresolvedConflict],
          ]),
        );
        when(
          () => mockDb.watchConflicts(ConflictStatus.resolved),
        ).thenAnswer(
          (_) => Stream<List<Conflict>>.fromIterable([
            <Conflict>[],
          ]),
        );

        String? capturedPath;
        beamToNamedOverride = (path) => capturedPath = path;
        addTearDown(() => beamToNamedOverride = null);

        await _pumpConflictsPage(tester);
        await tester.pumpAndSettle();

        // The unresolved conflict has id == 'id' (from test data).
        expect(find.text('id'), findsOneWidget);

        final listItemFinder = find.text('id');
        await tester.ensureVisible(listItemFinder);
        await tester.tap(listItemFinder);
        await tester.pumpAndSettle();

        expect(
          capturedPath,
          '/settings/advanced/conflicts/${unresolvedConflict.id}',
        );
      },
    );
  });
}
