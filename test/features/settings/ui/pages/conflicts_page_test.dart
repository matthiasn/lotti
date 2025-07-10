import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/advanced/conflicts_page.dart';
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

      final resolvedSegmentFinder = find.text('resolved');
      expect(resolvedSegmentFinder, findsOneWidget);

      final unresolvedSegmentFinder = find.text('unresolved');
      expect(unresolvedSegmentFinder, findsOneWidget);

      await tester.tap(resolvedSegmentFinder);
      await tester.pumpAndSettle();

      await tester.tap(unresolvedSegmentFinder);
      await tester.pumpAndSettle();
    });
  });
}
