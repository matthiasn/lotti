import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_reader.dart';

import '../front_pull_request_test_data.dart';

void main() {
  final tasks = [
    for (var i = 1; i <= 5; i++)
      FrontIndexRow(
        kind: FrontDestinationKind.task,
        id: 't-$i',
        title: 'Penguin chore $i',
      ),
  ];
  const project = FrontIndexRow(
    kind: FrontDestinationKind.project,
    id: 'p-1',
    title: 'Colony census',
  );
  const goal = FrontIndexRow(
    kind: FrontDestinationKind.goal,
    id: 'g-1',
    title: 'Healthy colony',
  );
  final visible = frontVisibleRows([...tasks, project, goal]);

  Map<String, Object?> item(FrontIndexRow row, {String? note}) => {
    'kind': row.kind == FrontDestinationKind.project ? 'project' : 'task',
    'id': row.id,
    'title': row.title,
    'note': ?note,
  };
  Map<String, Object?> text(String words) => {
    'component': 'Text',
    'text': words,
  };
  Map<String, Object?> cards(
    List<Map<String, Object?>> items, {
    String? caption,
  }) => {
    'component': 'TaskCards',
    'items': items,
    'caption': ?caption,
  };
  String link(FrontIndexRow row) =>
      '[${row.title}](lotti://${row.kind.wireName}/${row.id})';

  FrontReply read({
    String prose = 'Here.',
    List<Object?> components = const [],
    Set<String> available = const {},
    List<FrontIndexRow> dueRows = const [],
    Set<String> closedTaskIds = const {},
    List<FrontFoundPullRequest> shownPullRequests = const [],
    List<FrontFoundPullRequest> foundPullRequests = const [],
  }) => readFrontReply(
    prose: prose,
    components: components,
    visible: visible,
    available: available,
    dueRows: dueRows,
    closedTaskIds: closedTaskIds,
    link: (words) => words,
    pullRequests: {
      for (final pr in [...shownPullRequests, ...foundPullRequests]) pr.key: pr,
    },
    foundPullRequests: foundPullRequests,
  );

  test('an answer still being written may have no prose yet: its '
      'components are read, and there are no words', () {
    final reply = readFrontReply(
      prose: '',
      components: const [
        {
          'component': 'TaskCards',
          'ids': ['task:t-1'],
        },
      ],
      visible: visible,
      available: const {},
      dueRows: const [],
      link: (words) => words,
      proseRequired: false,
    );

    expect(reply.text, isEmpty);
    expect(
      [for (final component in reply.components) component['component']],
      [FrontReplyComponents.taskCards],
    );
  });

  test('prose alone is one Text of her words, linked', () {
    final reply = readFrontReply(
      prose: '  Nothing is due.  ',
      components: const [],
      visible: visible,
      available: const {},
      dueRows: const [],
      link: (words) => '<$words>',
    );

    expect(reply.text, '<Nothing is due.>');
    expect(reply.components, [text('<Nothing is due.>')]);
    expect(reply.dropped, isEmpty);
  });

  test('her prose leads what she composed, in her order: a label, cards '
      'with notes, a chart, replies to tap', () {
    final reply = read(
      prose: 'One is overdue, and here is your week.',
      components: [
        {'component': 'Text', 'text': 'Overdue'},
        {
          'component': 'TaskCards',
          'caption': ' Overdue tasks ',
          'ids': ['task:t-1', 't-2', 'project:p-1'],
          'notes': [' 2h 10m ', '', 'ignored on a project'],
        },
        {'component': 'LoggedTimeChart', 'caption': 'Time this week'},
        {
          'component': 'QuickReplies',
          'options': [' Break it down ', '', 'No', 'Later', 'A fourth'],
        },
      ],
      available: {FrontReplyComponents.loggedTimeChart},
    );

    expect(reply.components, [
      text('One is overdue, and here is your week.'),
      text('Overdue'),
      cards(
        // A bare id is a task's; a note is a task card's only.
        [item(tasks[0], note: '2h 10m'), item(tasks[1]), item(project)],
        caption: 'Overdue tasks',
      ),
      {'component': 'LoggedTimeChart', 'caption': 'Time this week'},
      {
        'component': 'QuickReplies',
        // Trimmed, blanks out, at most three.
        'options': ['Break it down', 'No', 'Later'],
      },
    ]);
    // Only her prose is spoken: not the label, not a caption.
    expect(reply.text, 'One is overdue, and here is your week.');
    expect(reply.dropped, isEmpty);
  });

  group('a list of task links in her prose is drawn as cards anyway:', () {
    test("whatever the line says around a task's link becomes its note; "
        'her text keeps the list, since cards are not read aloud', () {
      final said = [
        'Three took time:',
        '',
        '- ${link(tasks[0])} — 2h 10m',
        '- [ ] **${link(tasks[1])}**',
        '',
        '1. Due today: ${link(tasks[2])}',
        '- ${link(project)}',
        '',
        'Tell me if you want more.',
      ].join('\n');
      final reply = read(prose: said);

      expect(reply.components, [
        text('Three took time:'),
        cards([
          item(tasks[0], note: '2h 10m'),
          item(tasks[1]),
          item(tasks[2], note: 'Due today'),
          item(project),
        ]),
        text('Tell me if you want more.'),
      ]);
      expect(reply.text, said);
    });

    test('a single listed task, and prose that is nothing but the list, are '
        'cards too', () {
      expect(read(prose: 'Due today:\n\n- ${link(tasks[0])}').components, [
        text('Due today:'),
        cards([item(tasks[0])]),
      ]);
      final list = '- ${link(tasks[0])}\n- ${link(tasks[1])}';
      final alone = read(prose: list);
      expect(alone.components, [
        cards([item(tasks[0]), item(tasks[1])]),
      ]);
      expect(alone.text, list);
    });

    test('lists parted by words are separate lists', () {
      final reply = read(
        prose: [
          'Overdue:',
          '- ${link(tasks[0])}',
          'Due today:',
          '- ${link(tasks[1])}',
        ].join('\n'),
      );

      expect(reply.components, [
        text('Overdue:'),
        cards([item(tasks[0])]),
        text('Due today:'),
        cards([item(tasks[1])]),
      ]);
    });

    test('a line that is no list line, links nothing the turn saw, links '
        'two things, says a sentence, or gives a project more words stays '
        'her words', () {
      final said = [
        'I looked at ${link(tasks[0])} first.',
        '- [Unknown](lotti://task/nope)',
        '- ${link(tasks[1])} and ${link(tasks[2])}',
        '- ${link(goal)}',
        '- plain words',
        '- ${link(tasks[3])} is blocked until the supplier confirms the date',
        '- ${link(project)} — urgent',
      ].join('\n');

      expect(read(prose: said).components, [text(said)]);
    });
  });

  test('a task is listed once, where it first stands, and never when a '
      'closed-task card shows it', () {
    final reply = read(
      prose: 'Both:',
      components: [
        {
          'component': 'TaskCards',
          'ids': ['task:t-1', 'task:t-1', 'task:t-2', 'task:t-3'],
        },
        {
          'component': 'TaskCards',
          'ids': ['task:t-2'],
        },
      ],
      closedTaskIds: {'t-3'},
    );

    expect(reply.components, [
      text('Both:'),
      cards([item(tasks[0]), item(tasks[1])]),
    ]);
  });

  test('due tasks she listed nowhere follow as one more list, and what a '
      'lookup made that she did not place follows in catalog order', () {
    final reply = read(
      prose: 'Three are due.',
      components: [
        {
          'component': 'TaskCards',
          'ids': ['task:t-2'],
        },
      ],
      dueRows: [tasks[0], tasks[1], tasks[2]],
      available: {
        FrontReplyComponents.pullRequestChart,
        FrontReplyComponents.closedTasks,
      },
    );

    expect(reply.components, [
      text('Three are due.'),
      cards([item(tasks[1])]),
      cards([item(tasks[0]), item(tasks[2])]),
      {'component': 'ClosedTasks'},
      {'component': 'PullRequestChart'},
    ]);
  });

  group('pull request cards', () {
    final shown = foundPullRequest(1, taskId: 'igloo');
    final found = [foundPullRequest(2), foundPullRequest(3)];
    Map<String, Object?> pullRequestCards(
      List<FrontFoundPullRequest> prs, {
      String? caption,
    }) => {
      'component': 'PullRequestCards',
      'items': [for (final pr in prs) frontPullRequestCardToJson(pr.card)],
      'caption': ?caption,
    };

    test('ids she places are stored as each one and its task, in her '
        'order; found ones she placed nowhere follow, each once', () {
      final reply = read(
        prose: 'That was the fish ledger.',
        components: [
          {
            'component': 'PullRequestCards',
            'caption': 'Pull requests found',
            'ids': [
              ' penguin/colony#3',
              'penguin/colony#1',
              'penguin/colony#3',
            ],
          },
        ],
        shownPullRequests: [shown],
        foundPullRequests: found,
      );

      expect(reply.components, [
        text('That was the fish ledger.'),
        pullRequestCards([
          found[1],
          shown,
        ], caption: 'Pull requests found'),
        pullRequestCards([found[0]]),
      ]);
      expect(reply.dropped, isEmpty);
    });

    test('an id the turn never saw is dropped and named', () {
      final reply = read(
        components: [
          {
            'component': 'PullRequestCards',
            'ids': ['penguin/colony#99', 7],
          },
        ],
        shownPullRequests: [shown],
      );

      expect(reply.components, [text('Here.')]);
      expect(reply.dropped, hasLength(2));
      expect(reply.dropped.first, startsWith('penguin/colony#99, not a pull'));
    });

    test('found pull requests are drawn though she placed none', () {
      expect(read(foundPullRequests: found).components, [
        text('Here.'),
        pullRequestCards(found),
      ]);
    });
  });

  test('a reply without prose is refused: there is nothing to say', () {
    expect(
      () => read(
        prose: '  ',
        components: [
          {
            'component': 'TaskCards',
            'ids': ['task:t-1'],
          },
        ],
      ),
      throwsA(
        isA<FrontReplyException>()
            .having((e) => e.message, 'message', contains('no prose'))
            .having((e) => '$e', 'toString', contains('no prose')),
      ),
    );
  });

  group('drops what it cannot draw, names it, and still keeps her prose:', () {
    test('a card the turn could not see, or one of a kind not drawn', () {
      final reply = read(
        components: [
          {
            'component': 'TaskCards',
            'ids': ['task:made-up', 'goal:g-1', 7, 'task:t-1'],
          },
        ],
      );

      expect(reply.components, [
        text('Here.'),
        cards([item(tasks[0])]),
      ]);
      expect(reply.dropped, [
        startsWith('task:made-up, not a task or project'),
        startsWith('goal:g-1, not a task or project'),
        startsWith('7, not a task or project'),
      ]);
    });

    test('a chart no lookup made this turn; one placed twice is drawn '
        'once', () {
      final reply = read(
        components: [
          {'component': 'LoggedTimeChart'},
          {'component': 'ClosedTasks'},
          {'component': 'ClosedTasks'},
        ],
        available: {FrontReplyComponents.closedTasks},
      );

      expect(reply.components, [
        text('Here.'),
        {'component': 'ClosedTasks'},
      ]);
      expect(reply.dropped, [
        'LoggedTimeChart, which no lookup made this turn',
      ]);
    });

    test('a component of no known shape; empty ones are no mistake', () {
      final reply = read(
        components: [
          {'component': 'Heading', 'text': 'Due'},
          {'component': 'TaskCards'},
          'Text',
          {'component': 'Text', 'text': '  '},
          {'component': 'QuickReplies', 'options': <Object?>[]},
        ],
      );

      expect(reply.components, [text('Here.')]);
      expect(reply.dropped, hasLength(3));
      expect(reply.dropped.first, contains('not a component'));
    });
  });

  group('properties', () {
    const lookups = FrontReplyComponents.fromLookups;
    final cardable = [...tasks, project];

    // A component is encoded as an int: its kind by v % 4, its content by
    // v ~/ 4.
    Object componentOf(int v, Set<String> available) {
      final n = v ~/ 4;
      return switch (v % 4) {
        0 => {'component': 'Text', 'text': 'Label $n'},
        1 => {
          'component': 'TaskCards',
          'ids': [
            for (var i = 0; i <= n % 3; i++)
              () {
                final row = cardable[(n + i) % cardable.length];
                return '${row.kind.wireName}:${row.id}';
              }(),
          ],
        },
        2 => {
          'component': 'QuickReplies',
          'options': ['Yes $n'],
        },
        _ when available.isEmpty => {'component': 'Text', 'text': 'More $n'},
        _ => {'component': available.elementAt(n % available.length)},
      };
    }

    glados.Glados3(
      glados.any.list(glados.any.intInRange(0, 80)),
      glados.any.list(glados.any.intInRange(0, tasks.length)),
      glados.any.intInRange(0, 1 << lookups.length),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'any composition leads with her prose, loses nothing a lookup found '
      'and draws nothing twice',
      (encoded, dueIndexes, mask) {
        final available = {
          for (final (i, type) in lookups.indexed)
            if (mask & (1 << i) != 0) type,
        };
        final dueRows = [for (final i in dueIndexes) tasks[i]];

        final reply = read(
          prose: 'Lead.',
          components: [for (final v in encoded) componentOf(v, available)],
          available: available,
          dueRows: dueRows,
        );

        // Every component was drawable, so nothing was left out.
        expect(reply.dropped, isEmpty);
        expect(reply.components.first, text('Lead.'));
        // What is spoken is her prose and nothing else.
        expect(reply.text, 'Lead.');
        final listed = [
          for (final component in reply.components)
            if (component case {'items': final List<Object?> items})
              for (final item in items)
                '${(item! as Map)['kind']}:${(item as Map)['id']}',
        ];
        // Nothing twice, and every due task somewhere.
        expect(listed.toSet().length, listed.length);
        expect(
          {for (final row in dueRows) 'task:${row.id}'}.difference(
            listed.toSet(),
          ),
          isEmpty,
        );
        // No list is ever empty.
        expect(
          reply.components.every(
            (c) => c['items'] is! List || (c['items']! as List).isNotEmpty,
          ),
          isTrue,
        );
        // Every lookup's component, exactly once.
        final placed = [
          for (final component in reply.components)
            if (lookups.contains(component['component']))
              component['component'],
        ];
        expect(placed.toSet(), available);
        expect(placed.length, available.length);
      },
      tags: 'glados',
    );
  });
}
