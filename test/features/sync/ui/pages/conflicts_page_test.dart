import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockJournalDb = MockJournalDb();

  group('ConflictsPage Widget Tests - ', () {
    setUp(() {
      getIt.registerSingleton<UserActivityService>(UserActivityService());
      when(() => mockJournalDb.watchConflicts(ConflictStatus.resolved))
          .thenAnswer(
        (_) => Stream<List<Conflict>>.fromIterable([
          [resolvedConflict],
        ]),
      );

      when(() => mockJournalDb.watchConflicts(ConflictStatus.unresolved))
          .thenAnswer(
        (_) => Stream<List<Conflict>>.fromIterable([
          [unresolvedConflict],
        ]),
      );

      getIt.registerSingleton<JournalDb>(mockJournalDb);
    });
    tearDown(getIt.reset);

    testWidgets('Conflicts list page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const ConflictsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sync Conflicts'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('syncFilter-unresolved')), findsOneWidget);
      expect(find.byKey(const ValueKey('syncFilter-resolved')), findsOneWidget);

      expect(find.text('Unresolved · 1 item'), findsOneWidget);
      expect(find.textContaining('Entity: Text'), findsOneWidget);
      expect(find.textContaining('ID: id'), findsOneWidget);

      await tester.tap(find.text('Resolved'));
      await tester.pumpAndSettle();

      expect(find.text('Resolved · 1 item'), findsOneWidget);
      expect(find.textContaining('Entity: Text'), findsOneWidget);
      expect(find.textContaining('ID: id'), findsOneWidget);
    });

    testWidgets('segmented filters stay pinned while scrolling',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 500,
            height: 1000,
            child: ConflictsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      final resolvedFilter = find.byKey(const ValueKey('syncFilter-resolved'));
      await tester.ensureVisible(resolvedFilter);
      await tester.tap(resolvedFilter);
      await tester.pumpAndSettle();

      expect(find.textContaining('Resolved · 1 item'), findsOneWidget);
    });
    testWidgets('shows empty state when streams emit no conflicts',
        (tester) async {
      when(() => mockJournalDb.watchConflicts(ConflictStatus.resolved))
          .thenAnswer(
        (_) => Stream<List<Conflict>>.fromIterable([
          <Conflict>[],
        ]),
      );

      when(() => mockJournalDb.watchConflicts(ConflictStatus.unresolved))
          .thenAnswer(
        (_) => Stream<List<Conflict>>.fromIterable([
          <Conflict>[],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 500,
            height: 1000,
            child: ConflictsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No conflicts detected'), findsOneWidget);
      expect(find.textContaining('0 items'), findsWidgets);
    });

    testWidgets('shows loader before the first conflict snapshot',
        (tester) async {
      final unresolvedController = StreamController<List<Conflict>>();
      final resolvedController = StreamController<List<Conflict>>();

      when(() => mockJournalDb.watchConflicts(ConflictStatus.unresolved))
          .thenAnswer((_) => unresolvedController.stream);
      when(() => mockJournalDb.watchConflicts(ConflictStatus.resolved))
          .thenAnswer((_) => resolvedController.stream);

      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 500,
            height: 1000,
            child: ConflictsPage(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      unresolvedController.add(<Conflict>[]);
      resolvedController.add(<Conflict>[]);

      await tester.pumpAndSettle();

      expect(find.text('No conflicts detected'), findsOneWidget);

      await unresolvedController.close();
      await resolvedController.close();
    });
  });
}
