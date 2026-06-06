import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/tasks_counts.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;

  setUp(() async {
    mocks = await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  group('TaskCounts', () {
    testWidgets('renders one count chip per status with its DB count', (
      tester,
    ) async {
      final countsByStatus = <String, int>{
        'OPEN': 3,
        'IN PROGRESS': 2,
        'ON HOLD': 5,
        'BLOCKED': 0,
        'DONE': 42,
      };
      when(
        () => mocks.journalDb.getTasksCount(statuses: any(named: 'statuses')),
      ).thenAnswer((invocation) async {
        final statuses =
            invocation.namedArguments[#statuses] as List<String>? ?? [];
        return countsByStatus[statuses.single] ?? -1;
      });

      await tester.pumpWidget(makeTestableWidget(const TaskCounts()));
      await tester.pump();

      expect(find.text('Tasks:'), findsOneWidget);
      expect(find.text('3 Open'), findsOneWidget);
      expect(find.text('2 In Progress'), findsOneWidget);
      expect(find.text('5 On Hold'), findsOneWidget);
      expect(find.text('0 Blocked'), findsOneWidget);
      expect(find.text('42 Done'), findsOneWidget);
    });

    testWidgets('hides a chip while its count future is unresolved', (
      tester,
    ) async {
      final completer = Completer<int>();
      when(
        () => mocks.journalDb.getTasksCount(statuses: any(named: 'statuses')),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(makeTestableWidget(const TaskCounts()));
      await tester.pump();

      // Futures pending: all chips collapsed to nothing.
      expect(find.text('1 Open'), findsNothing);

      completer.complete(1);
      await tester.pump();
      await tester.pump();
      expect(find.text('1 Open'), findsOneWidget);
    });
  });

  group('FlaggedCount', () {
    testWidgets('renders the import-flag count', (tester) async {
      when(
        () => mocks.journalDb.getCountImportFlagEntries(),
      ).thenAnswer((_) async => 7);

      await tester.pumpWidget(makeTestableWidget(const FlaggedCount()));
      await tester.pump();

      expect(find.text('Flagged: 7'), findsOneWidget);
    });
  });
}
