import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_components.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

void main() {
  FrontEntityReference task(String id) =>
      FrontEntityReference(kind: FrontEntityKind.task, id: id, title: 'T $id');
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

  test('a reply is a root listing its parts in her order, each with the '
      "reply's own data", () {
    final components = frontReplyComponents(
      parts: [
        const FrontReplyText('Overdue:'),
        FrontReplyCards([task('t-1')]),
        const FrontReplyShow(FrontReplyAttachment.loggedTimeChart),
        const FrontReplyShow(FrontReplyAttachment.closedTasks),
        const FrontReplyShow(FrontReplyAttachment.pullRequestChart),
      ],
      closedTasks: closed,
      loggedTime: loggedTime,
      pullRequests: pullRequests,
      due: due,
    );

    expect(components, [
      {
        'id': 'root',
        'component': 'FrontReply',
        'parts': [
          'text-0',
          'cards-1',
          'logged_time_chart',
          'closed_tasks',
          'pull_request_chart',
        ],
      },
      {'id': 'text-0', 'component': 'FrontText', 'markdown': 'Overdue:'},
      {
        'id': 'cards-1',
        'component': 'FrontCards',
        'cards': [task('t-1').toJson()],
        'due': due.toJson(),
      },
      {
        'id': 'logged_time_chart',
        'component': 'FrontLoggedTimeChart',
        'chart': loggedTime.toJson(),
      },
      {
        'id': 'closed_tasks',
        'component': 'FrontClosedTasks',
        'tasks': [closed.single.toJson()],
      },
      {
        'id': 'pull_request_chart',
        'component': 'FrontPullRequestChart',
        'chart': pullRequests.toJson(),
      },
    ]);
  });

  test('a card already shown is not listed again, a list left empty is left '
      'out, and a part whose data the reply does not carry draws nothing', () {
    final components = frontReplyComponents(
      parts: [
        const FrontReplyText('Made it.'),
        FrontReplyCards([task('t-1'), task('t-2')]),
        FrontReplyCards([task('t-1')]),
        const FrontReplyShow(FrontReplyAttachment.loggedTimeChart),
      ],
      shown: {'t-1'},
    );

    expect(components.first['parts'], ['text-0', 'cards-1']);
    expect(components[2]['cards'], [task('t-2').toJson()]);
  });

  test('an attachment placed twice is drawn once, where it first stands: '
      'two components never share an id', () {
    final components = frontReplyComponents(
      parts: [
        const FrontReplyShow(FrontReplyAttachment.loggedTimeChart),
        const FrontReplyText('12h.'),
        const FrontReplyShow(FrontReplyAttachment.loggedTimeChart),
      ],
      loggedTime: loggedTime,
    );

    expect(components.first['parts'], ['logged_time_chart', 'text-1']);
  });

  test('the due window labels the one list of a reply, never one of two', () {
    final one = frontReplyComponents(
      parts: [
        FrontReplyCards([task('t-1')]),
      ],
      due: due,
    );
    final two = frontReplyComponents(
      parts: [
        FrontReplyCards([task('t-1')]),
        FrontReplyCards([task('t-2')]),
      ],
      due: due,
    );

    expect(one[1]['due'], due.toJson());
    expect(two.skip(1).map((c) => c.containsKey('due')), [false, false]);
  });

  group('properties', () {
    const types = {
      FrontReplyComponentTypes.text,
      FrontReplyComponentTypes.cards,
      FrontReplyComponentTypes.closedTasks,
      FrontReplyComponentTypes.loggedTimeChart,
      FrontReplyComponentTypes.pullRequestChart,
    };

    // A part is encoded as an int: its kind by v % 3, its content by v ~/ 3.
    FrontReplyPart partOf(int v) {
      final n = v ~/ 3;
      return switch (v % 3) {
        0 => FrontReplyText('Words $n.'),
        1 => FrontReplyCards([task('t-${n % 4}'), task('t-${(n + 1) % 4}')]),
        _ => FrontReplyShow(
          FrontReplyAttachment.values[n % FrontReplyAttachment.values.length],
        ),
      };
    }

    glados.Glados2(
      glados.any.list(glados.any.intInRange(0, 40)),
      glados.any.intInRange(0, 16),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'the root lists every other component once, in part order, by a '
      'unique id of a catalog type',
      (encoded, mask) {
        final parts = [for (final v in encoded) partOf(v)];
        final components = frontReplyComponents(
          parts: parts,
          closedTasks: mask & 1 != 0 ? closed : null,
          loggedTime: mask & 2 != 0 ? loggedTime : null,
          pullRequests: mask & 4 != 0 ? pullRequests : null,
          shown: mask & 8 != 0 ? {'t-0'} : const {},
        );

        final root = components.first;
        expect(root['id'], 'root');
        expect(root['component'], FrontReplyComponentTypes.reply);
        final rest = components.skip(1).toList();
        expect(root['parts'], [for (final c in rest) c['id']]);
        expect({for (final c in rest) c['id']}.length, rest.length);
        expect(rest.every((c) => types.contains(c['component'])), isTrue);
        // Her words are never dropped: one text component per text part.
        expect(
          rest.where((c) => c['component'] == FrontReplyComponentTypes.text),
          hasLength(parts.whereType<FrontReplyText>().length),
        );
        // A shown card never reappears in a list.
        if (mask & 8 != 0) {
          for (final c in rest) {
            if (c['component'] != FrontReplyComponentTypes.cards) continue;
            expect(
              (c['cards']! as List).map((card) => (card as Map)['id']),
              isNot(contains('t-0')),
            );
          }
        }
      },
      tags: 'glados',
    );
  });
}
