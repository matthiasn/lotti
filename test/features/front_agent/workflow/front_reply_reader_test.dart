import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_reader.dart';

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
  Map<String, Object?> cards(List<Map<String, Object?>> items) => {
    'component': 'TaskCards',
    'items': items,
  };
  String link(FrontIndexRow row) =>
      '[${row.title}](lotti://${row.kind.wireName}/${row.id})';

  FrontReply read({
    Object? message,
    Object? components,
    Set<String> available = const {},
    List<FrontIndexRow> dueRows = const [],
    Set<String> closedTaskIds = const {},
  }) => readFrontReply(
    message: message,
    components: components,
    visible: visible,
    available: available,
    dueRows: dueRows,
    closedTaskIds: closedTaskIds,
    link: (words) => words,
  );

  test('a message alone is one Text of her words, linked', () {
    final reply = readFrontReply(
      message: '  Nothing is due.  ',
      components: null,
      visible: visible,
      available: const {},
      dueRows: const [],
      link: (words) => '<$words>',
    );

    expect(reply.text, '<Nothing is due.>');
    expect(reply.components, [text('<Nothing is due.>')]);
    expect(reply.dropped, isEmpty);
  });

  test('components keep her order: words, cards with a note, words, a '
      'chart, replies to tap', () {
    final reply = read(
      components: [
        {'component': 'Text', 'text': 'One is overdue:'},
        {
          'component': 'TaskCards',
          'items': ['task:t-1'],
        },
        {'component': 'Text', 'text': 'And these took time:'},
        {
          'component': 'TaskCards',
          'items': [
            {'ref': 'task:t-2', 'note': ' 2h 10m '},
            {'ref': 'project:p-1'},
          ],
        },
        {'component': 'LoggedTimeChart'},
        {
          'component': 'QuickReplies',
          'options': [' Break it down ', '', 'No', 'Later', 'A fourth'],
        },
      ],
      available: {FrontReplyComponents.loggedTimeChart},
    );

    expect(reply.components, [
      text('One is overdue:'),
      cards([item(tasks[0])]),
      text('And these took time:'),
      cards([item(tasks[1], note: '2h 10m'), item(project)]),
      {'component': 'LoggedTimeChart'},
      {
        'component': 'QuickReplies',
        // Trimmed, blanks out, at most three.
        'options': ['Break it down', 'No', 'Later'],
      },
    ]);
    expect(reply.text, 'One is overdue:\n\nAnd these took time:');
    expect(reply.dropped, isEmpty);
  });

  test('a message beside components leads them as her words', () {
    final reply = read(
      message: 'Here:',
      components: [
        {
          'component': 'TaskCards',
          'items': ['task:t-1'],
        },
      ],
    );

    expect(reply.components, [
      text('Here:'),
      cards([item(tasks[0])]),
    ]);
  });

  test('her words are said once: a message beside Text components repeats '
      'them, so the components stand alone', () {
    final reply = read(
      message: 'You opened 12 pull requests.',
      components: [
        {'component': 'Text', 'text': 'You opened 12 pull requests.'},
        {'component': 'PullRequestChart'},
      ],
      available: {FrontReplyComponents.pullRequestChart},
    );

    expect(reply.text, 'You opened 12 pull requests.');
    expect(reply.components, [
      text('You opened 12 pull requests.'),
      {'component': 'PullRequestChart'},
    ]);
    // A blank Text is no words of hers: the message still leads.
    expect(
      read(
        message: 'Here.',
        components: [
          {'component': 'Text', 'text': '  '},
        ],
      ).text,
      'Here.',
    );
  });

  group('a list of task links in her words is drawn as cards anyway:', () {
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
      final reply = read(message: said);

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

    test("a project line that says more stays her words: only a task's "
        'card shows a note', () {
      final said = 'Found:\n- ${link(project)} — urgent\n- ${link(tasks[0])}';

      expect(read(message: said).components, [
        text('Found:\n- ${link(project)} — urgent'),
        cards([item(tasks[0])]),
      ]);
      // A note she gives a project in a component is not kept either.
      expect(
        read(
          message: 'Here:',
          components: [
            {
              'component': 'TaskCards',
              'items': [
                {'ref': 'project:p-1', 'note': 'urgent'},
              ],
            },
          ],
        ).components.last,
        cards([item(project)]),
      );
    });

    test('a single listed task is a card too', () {
      final reply = read(message: 'Due today:\n\n- ${link(tasks[0])}');

      expect(reply.components, [
        text('Due today:'),
        cards([item(tasks[0])]),
      ]);
    });

    test('lists parted by words are separate lists', () {
      final reply = read(
        message: [
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

    test('a line that is no list line, links nothing the turn saw, or '
        'links two things stays her words', () {
      final said = [
        'I looked at ${link(tasks[0])} first.',
        '- [Unknown](lotti://task/nope)',
        '- ${link(tasks[1])} and ${link(tasks[2])}',
        '- ${link(goal)}',
        '- plain words',
      ].join('\n');

      expect(read(message: said).components, [text(said)]);
    });

    test('a reply that is nothing but the list keeps it as her words: a '
        'reply must say something', () {
      final said = '- ${link(tasks[0])}\n- ${link(tasks[1])}';

      expect(read(message: said).components, [text(said)]);
    });

    test('it applies to a Text component as to a message', () {
      final reply = read(
        components: [
          {'component': 'Text', 'text': 'Found:\n- ${link(tasks[0])}'},
        ],
      );

      expect(reply.components, [
        text('Found:'),
        cards([item(tasks[0])]),
      ]);
    });
  });

  test('a task is listed once, where it first stands, and never when a '
      'closed-task card shows it', () {
    final reply = read(
      message: 'Both:',
      components: [
        {
          'component': 'TaskCards',
          'items': ['task:t-1', 'task:t-1', 'task:t-2', 'task:t-3'],
        },
        {
          'component': 'TaskCards',
          'items': ['task:t-2'],
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
      message: 'Three are due.',
      components: [
        {
          'component': 'TaskCards',
          'items': ['task:t-2'],
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

  test('a reply without words is refused: there is nothing to deliver', () {
    Matcher refused() => throwsA(
      isA<FrontReplyException>()
          .having((e) => e.message, 'message', contains('needs your words'))
          .having((e) => '$e', 'toString', contains('needs your words')),
    );

    expect(() => read(message: ' '), refused());
    expect(
      () => read(
        components: [
          {
            'component': 'TaskCards',
            'items': ['task:t-1'],
          },
          {'component': 'Text', 'text': '  '},
        ],
      ),
      refused(),
    );
  });

  group(
    'drops what it cannot draw, names it, and still delivers her words:',
    () {
      test('a card the turn could not see, or one of a kind not drawn', () {
        final reply = read(
          message: 'Here:',
          components: [
            {
              'component': 'TaskCards',
              'items': [
                'task:made-up',
                'goal:g-1',
                7,
                {'ref': 'task:nope'},
                'task:t-1',
              ],
            },
          ],
        );

        expect(reply.components, [
          text('Here:'),
          cards([item(tasks[0])]),
        ]);
        expect(reply.dropped, [
          startsWith('task:made-up, not a task or project'),
          startsWith('goal:g-1, not a task or project'),
          startsWith('7, not a task or project'),
          startsWith('task:nope, not a task or project'),
        ]);
      });

      test(
        'a chart no lookup made this turn; one placed twice is drawn once',
        () {
          final reply = read(
            message: '12h.',
            components: [
              {'component': 'LoggedTimeChart'},
              {'component': 'ClosedTasks'},
              {'component': 'ClosedTasks'},
            ],
            available: {FrontReplyComponents.closedTasks},
          );

          expect(reply.components, [
            text('12h.'),
            {'component': 'ClosedTasks'},
          ]);
          expect(reply.dropped, [
            'LoggedTimeChart, which no lookup made this turn',
          ]);
        },
      );

      test('components that are not a list, or one of no known shape', () {
        expect(read(message: 'Hi', components: 'cards').dropped, [
          'components, which is not a list',
        ]);
        final reply = read(
          message: 'Hi',
          components: [
            {'component': 'Heading', 'text': 'Due'},
            {'component': 'Text'},
            {'component': 'QuickReplies', 'options': <Object?>[]},
            'Text',
          ],
        );
        expect(reply.components, [text('Hi')]);
        // Empty quick replies draw nothing and are no mistake worth naming.
        expect(reply.dropped, hasLength(3));
        expect(reply.dropped.first, contains('not a component'));
      });
    },
  );

  group('properties', () {
    const lookups = FrontReplyComponents.fromLookups;
    final cardable = [...tasks, project];

    // A component is encoded as an int: its kind by v % 4, its content by
    // v ~/ 4.
    Object componentOf(int v, Set<String> available) {
      final n = v ~/ 4;
      return switch (v % 4) {
        0 => {'component': 'Text', 'text': 'Words $n.'},
        1 => {
          'component': 'TaskCards',
          'items': [
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
        _ when available.isEmpty => {'component': 'Text', 'text': 'More $n.'},
        _ => {'component': available.elementAt(n % available.length)},
      };
    }

    glados.Glados3(
      glados.any.list(glados.any.intInRange(0, 80)),
      glados.any.list(glados.any.intInRange(0, tasks.length)),
      glados.any.intInRange(0, 1 << lookups.length),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'any composition keeps her order, loses nothing a lookup found and '
      'draws nothing twice',
      (encoded, dueIndexes, mask) {
        final available = {
          for (final (i, type) in lookups.indexed)
            if (mask & (1 << i) != 0) type,
        };
        final components = [
          {'component': 'Text', 'text': 'Lead.'},
          for (final v in encoded) componentOf(v, available),
        ];
        final dueRows = [for (final i in dueIndexes) tasks[i]];

        final reply = read(
          components: components,
          available: available,
          dueRows: dueRows,
        );

        // Every component was drawable, so nothing was left out.
        expect(reply.dropped, isEmpty);
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
        // Her words, in her order, are the reply's text.
        final words = [
          for (final component in components)
            if (component case {'text': final String text}) text,
        ];
        expect(reply.text, words.join('\n\n'));
      },
      tags: 'glados',
    );
  });
}
