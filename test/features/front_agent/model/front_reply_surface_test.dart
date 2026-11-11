import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

void main() {
  Map<String, Object?> text(String words) => {
    'component': FrontReplyComponents.text,
    'text': words,
  };
  Map<String, Object?> cards(List<String> ids) => {
    'component': FrontReplyComponents.taskCards,
    'items': [
      for (final id in ids)
        FrontEntityReference(
          kind: FrontEntityKind.task,
          id: id,
          title: 'T $id',
        ).toJson(),
    ],
  };
  const range = InsightsRange(startDay: 20396, endDayExclusive: 20403);
  const loggedTime = FrontLoggedTimeChart(range: range, categoryIds: {});
  const pullRequests = FrontPullRequestChart(range: range, categoryIds: {});
  final closed = [
    FrontClosedTaskCard(
      id: 'c-1',
      title: 'Sweep the ice',
      closedAt: DateTime.utc(2026, 11, 8),
    ),
  ];
  final due = FrontDueSection(
    window: FrontDueWindow.today,
    today: DateTime(2026, 11, 10),
    through: DateTime(2026, 11, 10),
  );

  Map<Object?, Object?> created(FrontReplySurface surface) =>
      surface.message['createSurface']! as Map;
  List<Object?> components(FrontReplySurface surface) =>
      created(surface)['components']! as List;

  test('composes one v1.0 createSurface: a root listing her components in '
      "order, a lookup's component bound to the data the app wrote", () {
    final surface = FrontReplySurface.compose(
      surfaceId: 'reply-1',
      components: [
        text('One is due:'),
        cards(['t-1']),
        const {'component': FrontReplyComponents.loggedTimeChart},
        const {'component': FrontReplyComponents.closedTasks},
        const {'component': FrontReplyComponents.pullRequestChart},
      ],
      due: due,
      closedTasks: closed,
      loggedTime: loggedTime,
      pullRequests: pullRequests,
    );

    expect(surface.message['version'], '1.0');
    expect(surface.surfaceId, 'reply-1');
    expect(created(surface)['catalogId'], frontReplyCatalogId);
    expect(created(surface)['dataModel'], {
      'due': due.toJson(),
      'closedTasks': [closed.single.toJson()],
      'loggedTime': loggedTime.toJson(),
      'pullRequests': pullRequests.toJson(),
    });
    expect(components(surface), [
      {
        'id': 'root',
        'component': 'Reply',
        'children': ['c0', 'c1', 'c2', 'c3', 'c4'],
      },
      {'component': 'Text', 'text': 'One is due:', 'id': 'c0'},
      {
        ...cards(['t-1']),
        'id': 'c1',
        // The one list of a due answer is labelled with its window.
        'due': {'@path': '/due'},
      },
      {
        'component': 'LoggedTimeChart',
        'id': 'c2',
        'data': {'@path': '/loggedTime'},
      },
      {
        'component': 'ClosedTasks',
        'id': 'c3',
        'data': {'@path': '/closedTasks'},
      },
      {
        'component': 'PullRequestChart',
        'id': 'c4',
        'data': {'@path': '/pullRequests'},
      },
    ]);
  });

  test("a lookup's component the turn has no data for is left out, and "
      'separate lists carry no window', () {
    final surface = FrontReplySurface.compose(
      surfaceId: 'reply-1',
      components: [
        cards(['t-1']),
        const {'component': FrontReplyComponents.loggedTimeChart},
        cards(['t-2']),
        const {'component': FrontReplyComponents.closedTasks},
      ],
      due: due,
      closedTasks: const [],
    );

    expect(
      [for (final c in components(surface).skip(1)) (c! as Map)['component']],
      ['TaskCards', 'TaskCards'],
    );
    expect(
      components(surface).skip(1).every((c) => !(c! as Map).containsKey('due')),
      isTrue,
    );
    expect(created(surface)['dataModel'], {'due': due.toJson()});
  });

  test('reads a stored surface back, and nothing from a shape this build '
      'does not know', () {
    final surface = FrontReplySurface.compose(
      surfaceId: 'reply-1',
      components: [text('Hi.')],
    );

    expect(
      FrontReplySurface.fromJson(surface.message)?.message,
      surface.message,
    );
    expect('$surface', 'FrontReplySurface(reply-1)');
    for (final bad in <Object?>[
      null,
      'surface',
      const <String, Object?>{},
      {'version': '1.0'},
      {'version': '1.0', 'createSurface': 'x'},
      {
        'version': '1.0',
        'createSurface': {'surfaceId': 'r'},
      },
      {
        'version': 1,
        'createSurface': {'surfaceId': 'r', 'components': <Object?>[]},
      },
    ]) {
      expect(FrontReplySurface.fromJson(bad), isNull, reason: '$bad');
    }
  });

  test('knows what it draws: words alone, something to point at, and the '
      'tasks it shows', () {
    final words = FrontReplySurface.compose(
      surfaceId: 'r',
      components: [text('Hi.'), text('Bye.')],
    );
    final offer = FrontReplySurface.compose(
      surfaceId: 'r',
      components: [
        text('Break it down?'),
        const {
          'component': FrontReplyComponents.quickReplies,
          'options': ['Yes'],
        },
      ],
    );
    final rich = FrontReplySurface.compose(
      surfaceId: 'r',
      components: [
        text('Here:'),
        {
          'component': FrontReplyComponents.taskCards,
          'items': [
            const FrontEntityReference(
              kind: FrontEntityKind.task,
              id: 't-1',
              title: 'T',
            ).toJson(),
            const FrontEntityReference(
              kind: FrontEntityKind.project,
              id: 'p-1',
              title: 'P',
            ).toJson(),
          ],
        },
        const {'component': FrontReplyComponents.closedTasks},
      ],
      closedTasks: closed,
    );

    expect((words.wordsOnly, words.hasVisual), (true, false));
    expect(words.taskIds, isEmpty);
    // Replies to tap are drawn, but are nothing to point at.
    expect((offer.wordsOnly, offer.hasVisual), (false, false));
    expect((rich.wordsOnly, rich.hasVisual), (false, true));
    // Her cards' tasks, then the closed ones; a project is no task.
    expect(rich.taskIds, ['t-1', 'c-1']);
  });
}
