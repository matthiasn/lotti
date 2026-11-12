import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_cards.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/pull_request_row.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../github/pull_request_fixtures.dart';

void main() {
  late MockPullRequestService service;
  late List<String> opened;

  setUpAll(() {
    registerFallbackValue(prEntry(clock: {'a': 1}));
  });

  setUp(() {
    opened = [];
    service = MockPullRequestService();
    when(() => service.refresh(any())).thenAnswer(
      (invocation) async => PullRequestRefreshed(
        (invocation.positionalArguments.single as PullRequestEntry)
            .data
            .snapshot!,
      ),
    );
  });

  PullRequestEntry pr(String id, int number, String title) {
    final entry = prEntry(
      clock: {'a': 1},
      id: id,
      snapshot: prSnapshot(title: title),
    );
    return entry.copyWith(data: entry.data.copyWith(number: number));
  }

  Task task(String id, String title) => testTask.copyWith(
    meta: testTask.meta.copyWith(id: id),
    data: testTask.data.copyWith(title: title),
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<FrontPullRequestCard> cards,
    Map<String, List<PullRequestEntry>> held = const {},
    Map<String, Task?> tasks = const {},
  }) => withClock(Clock.fixed(prFixtureEpoch), () async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        FrontPullRequestCards(cards: cards, onOpenTask: opened.add),
        overrides: [
          for (final MapEntry(:key, :value) in held.entries)
            taskPullRequestsProvider(key).overrideWithValue(value),
          taskPreviewProvider.overrideWith(
            (ref, id) async => switch (tasks[id]) {
              final task? => TaskPreview(task: task),
              null => null,
            },
          ),
          pullRequestServiceProvider.overrideWithValue(service),
          pullRequestHoldersProvider.overrideWith(
            (ref, pr) => Stream.value(const {}),
          ),
          pullRequestSummaryProvider.overrideWith(
            (ref, entryId) => Stream.value(
              entryId == 'e-7'
                  ? const PullRequestSummary(
                      oneLiner: 'Adds the fish ledger.',
                      tldr: 'Adds the ledger the colony counts fish in.',
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  });

  testWidgets('each task gets the task page card: its title opens the task, '
      'its rows are the task page rows, title and one-liner, in her order', (
    tester,
  ) async {
    await pump(
      tester,
      cards: const [
        (key: 'matthiasn/lotti#8', taskId: 'ledger'),
        (key: 'matthiasn/lotti#3', taskId: 'igloo'),
        (key: 'matthiasn/lotti#7', taskId: 'ledger'),
      ],
      held: {
        'ledger': [pr('e-7', 7, 'Fish ledger'), pr('e-8', 8, 'Ledger totals')],
        'igloo': [pr('e-3', 3, 'Warmer igloo')],
      },
      tasks: {
        'ledger': task('ledger', 'Count the fish'),
        'igloo': task('igloo', 'Warm the igloo'),
      },
    );

    expect(
      tester
          .widgetList<PullRequestRow>(find.byType(PullRequestRow))
          .map((row) => (row.taskId, row.entry.data.number)),
      [('ledger', 8), ('ledger', 7), ('igloo', 3)],
    );
    expect(find.text('Count the fish'), findsOneWidget);
    expect(find.text('Warm the igloo'), findsOneWidget);
    expect(
      find.textContaining('Adds the fish ledger.', findRichText: true),
      findsOne,
    );

    await tester.tap(find.byKey(FrontPullRequestCardsKeys.task('igloo')));
    expect(opened, ['igloo']);
  });

  testWidgets('a pull request the task no longer holds is left out, and a '
      'task with none left, or that is gone, draws no card', (tester) async {
    await pump(
      tester,
      cards: const [
        (key: 'matthiasn/lotti#7', taskId: 'ledger'),
        (key: 'matthiasn/lotti#9', taskId: 'ledger'),
        (key: 'matthiasn/lotti#5', taskId: 'unlinked'),
        (key: 'matthiasn/lotti#3', taskId: 'deleted'),
      ],
      held: {
        'ledger': [pr('e-7', 7, 'Fish ledger')],
        'unlinked': const [],
        'deleted': [pr('e-3', 3, 'Warmer igloo')],
      },
      tasks: {'ledger': task('ledger', 'Count the fish')},
    );

    expect(
      tester
          .widgetList<PullRequestRow>(find.byType(PullRequestRow))
          .map((row) => row.entry.data.number),
      [7],
    );
    expect(
      find.byKey(FrontPullRequestCardsKeys.task('unlinked')),
      findsNothing,
    );
    expect(find.byKey(FrontPullRequestCardsKeys.task('deleted')), findsNothing);
  });
}
