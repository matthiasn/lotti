import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/link_pull_request_modal.dart';
import 'package:lotti/features/github/ui/pull_request_row.dart';
import 'package:lotti/features/github/ui/task_pull_requests_section.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../pull_request_fixtures.dart';

void main() {
  const taskId = 'task-1';
  late MockPullRequestService service;

  setUpAll(() {
    registerFallbackValue(prEntry(clock: {'a': 1}));
  });

  setUp(() {
    service = MockPullRequestService();
    when(() => service.refresh(any())).thenAnswer(
      (invocation) async => PullRequestRefreshed(
        (invocation.positionalArguments.single as PullRequestEntry)
            .data
            .snapshot!,
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    List<PullRequestEntry> entries = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const TaskPullRequestsSection(taskId: taskId),
        overrides: [
          taskPullRequestsProvider(taskId).overrideWithValue(entries),
          pullRequestServiceProvider.overrideWithValue(service),
          pullRequestHoldersProvider.overrideWith(
            (ref, pr) => Stream.value(const {}),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'with none linked, the card is one worded action that opens the link '
    'modal',
    (tester) async {
      await pump(tester);

      expect(find.text('Pull requests'), findsOneWidget);
      expect(
        find.text('Follow its checks, reviews and status here.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('pull-requests-link')), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('pull-requests-empty-action')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(LinkPullRequestKeys.urlField), findsOneWidget);
    },
  );

  testWidgets(
    'lists the linked pull requests in order, with the link action in the '
    'header',
    (tester) async {
      PullRequestEntry pr(String id, int number, String title) {
        final e = prEntry(
          clock: {'a': 1},
          id: id,
          snapshot: prSnapshot(title: title),
        );
        return e.copyWith(data: e.data.copyWith(number: number));
      }

      await withClock(
        Clock.fixed(prFixtureEpoch),
        () => pump(
          tester,
          entries: [pr('a', 3, 'First'), pr('b', 9, 'Second')],
        ),
      );

      final rows = tester
          .widgetList<PullRequestRow>(find.byType(PullRequestRow))
          .map((row) => row.entry.data.number);
      expect(rows, [3, 9]);
      expect(find.text('#3 First'), findsOneWidget);
      expect(find.byKey(const ValueKey('pull-requests-link')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pull-requests-empty-action')),
        findsNothing,
      );
    },
  );
}
