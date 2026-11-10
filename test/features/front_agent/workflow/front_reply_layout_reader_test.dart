import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_layout_reader.dart';

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

  FrontEntityReference ref(FrontIndexRow row) => FrontEntityReference(
    kind: row.kind == FrontDestinationKind.project
        ? FrontEntityKind.project
        : FrontEntityKind.task,
    id: row.id,
    title: row.title,
  );

  FrontReplyLayout read({
    Object? message,
    Object? parts,
    Set<FrontReplyAttachment> available = const {},
    List<FrontIndexRow> dueRows = const [],
  }) => readFrontReplyLayout(
    message: message,
    parts: parts,
    visible: visible,
    available: available,
    dueRows: dueRows,
    link: (words) => '<$words>',
  );

  Matcher refused(String text) => throwsA(
    isA<FrontReplyLayoutException>()
        .having((e) => e.message, 'message', contains(text))
        // What she is told is what a log of the refusal says.
        .having((e) => e.toString(), 'toString', contains(text)),
  );

  test('a message alone is one part of her words, linked', () {
    final reply = read(message: '  Nothing is due.  ');

    expect(reply.text, '<Nothing is due.>');
    expect(reply.parts, [const FrontReplyText('<Nothing is due.>')]);
  });

  test('parts keep her order: words, cards, words, a chart', () {
    final reply = read(
      parts: [
        {'text': 'One is overdue:'},
        {
          'cards': ['task:t-1'],
        },
        {'text': 'And two are due:'},
        {
          'cards': ['task:t-2', 'project:p-1'],
        },
        {'show': 'logged_time_chart'},
      ],
      available: {FrontReplyAttachment.loggedTimeChart},
    );

    expect(reply.parts, [
      const FrontReplyText('<One is overdue:>'),
      FrontReplyCards([ref(tasks[0])]),
      const FrontReplyText('<And two are due:>'),
      FrontReplyCards([ref(tasks[1]), ref(project)]),
      const FrontReplyShow(FrontReplyAttachment.loggedTimeChart),
    ]);
    expect(reply.text, '<One is overdue:>\n\n<And two are due:>');
  });

  test('a message beside parts leads them as her words', () {
    final reply = read(
      message: 'Here:',
      parts: [
        {
          'cards': ['task:t-1'],
        },
      ],
    );

    expect(reply.parts, [
      const FrontReplyText('<Here:>'),
      FrontReplyCards([ref(tasks[0])]),
    ]);
  });

  test('a task listed twice is drawn where she first put it', () {
    final reply = read(
      parts: [
        {'text': 'Both:'},
        {
          'cards': ['task:t-1', 'task:t-1', 'task:t-2'],
        },
        {
          'cards': ['task:t-2'],
        },
      ],
    );

    expect(reply.parts, [
      const FrontReplyText('<Both:>'),
      FrontReplyCards([ref(tasks[0]), ref(tasks[1])]),
    ]);
  });

  test('due tasks she did not list follow as one more list, and what a '
      'lookup made that she did not place follows in catalog order', () {
    final reply = read(
      message: 'Three are due.',
      parts: [
        {
          'cards': ['task:t-2'],
        },
      ],
      dueRows: [tasks[0], tasks[1], tasks[2]],
      available: {
        FrontReplyAttachment.pullRequestChart,
        FrontReplyAttachment.closedTasks,
      },
    );

    expect(reply.parts, [
      const FrontReplyText('<Three are due.>'),
      FrontReplyCards([ref(tasks[1])]),
      FrontReplyCards([ref(tasks[0]), ref(tasks[2])]),
      const FrontReplyShow(FrontReplyAttachment.closedTasks),
      const FrontReplyShow(FrontReplyAttachment.pullRequestChart),
    ]);
  });

  test('an empty text part is skipped, not refused', () {
    final reply = read(
      parts: [
        {'text': '  '},
        {'text': 'Done.'},
      ],
    );

    expect(reply.parts, [const FrontReplyText('<Done.>')]);
  });

  test('a reply without words is refused: there is nothing to deliver', () {
    expect(() => read(message: ' '), refused('needs your words'));
    expect(
      () => read(
        parts: [
          {
            'cards': ['task:t-1'],
          },
        ],
      ),
      refused('needs your words'),
    );
  });

  group(
    'drops what it cannot draw, names it, and still delivers her words:',
    () {
      test('a card the turn could not see, or one of a kind not drawn', () {
        final reply = read(
          message: 'Here:',
          parts: [
            {
              'cards': ['task:made-up', 'goal:g-1', 7, 'task:t-1'],
            },
          ],
        );

        expect(reply.parts, [
          const FrontReplyText('<Here:>'),
          FrontReplyCards([ref(tasks[0])]),
        ]);
        expect(reply.dropped, [
          startsWith('task:made-up, not a task or project'),
          startsWith('goal:g-1, not a task or project'),
          startsWith('7, not a task or project'),
        ]);
      });

      test('a chart no lookup made this turn', () {
        final reply = read(
          message: '12h.',
          parts: [
            {'show': 'logged_time_chart'},
            {'show': 'weather'},
          ],
          available: {FrontReplyAttachment.closedTasks},
        );

        expect(reply.parts, [
          const FrontReplyText('<12h.>'),
          const FrontReplyShow(FrontReplyAttachment.closedTasks),
        ]);
        expect(reply.dropped, [
          'show "logged_time_chart", which no lookup made this turn',
          'show "weather", which no lookup made this turn',
        ]);
      });

      test('parts that are not a list, or a part of no known shape', () {
        expect(read(message: 'Hi', parts: 'cards').dropped, [
          'parts, which is not a list',
        ]);
        final reply = read(
          message: 'Hi',
          parts: [
            {'heading': 'Due'},
          ],
        );
        expect(reply.parts, [const FrontReplyText('<Hi>')]);
        expect(reply.dropped.single, contains('not a part'));
      });

      test('a reply with everything drawable drops nothing', () {
        expect(read(message: 'Hi').dropped, isEmpty);
      });
    },
  );

  group('properties', () {
    const attachments = FrontReplyAttachment.values;
    final cardable = [...tasks, project];

    // A part is encoded as an int: its kind by v % 3, its content by v ~/ 3.
    Object partOf(int v, Set<FrontReplyAttachment> available) {
      final n = v ~/ 3;
      return switch (v % 3) {
        0 => {'text': 'Words $n.'},
        1 => {
          'cards': [
            for (var i = 0; i <= n % 3; i++)
              keyOf(cardable[(n + i) % cardable.length]),
          ],
        },
        _ when available.isEmpty => {'text': 'More words $n.'},
        _ => {'show': available.elementAt(n % available.length).wireName},
      };
    }

    glados.Glados3(
      glados.any.list(glados.any.intInRange(0, 60)),
      glados.any.list(glados.any.intInRange(0, tasks.length)),
      glados.any.intInRange(0, 1 << attachments.length),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'any composition keeps her order, loses nothing a lookup found and '
      'draws nothing twice',
      (encoded, dueIndexes, mask) {
        final available = {
          for (final (i, a) in attachments.indexed)
            if (mask & (1 << i) != 0) a,
        };
        final parts = [
          {'text': 'Lead.'},
          for (final v in encoded) partOf(v, available),
        ];
        final dueRows = [for (final i in dueIndexes) tasks[i]];

        final reply = read(
          parts: parts,
          available: available,
          dueRows: dueRows,
        );
        // Every part was drawable, so nothing was left out.
        expect(reply.dropped, isEmpty);

        final cards = [
          for (final part in reply.parts.whereType<FrontReplyCards>())
            ...part.cards,
        ];
        final keys = [for (final card in cards) '${card.kind.name}:${card.id}'];
        // Nothing twice, and every due task somewhere.
        expect(keys.toSet().length, keys.length);
        expect(
          {for (final row in dueRows) 'task:${row.id}'}.difference(
            keys.toSet(),
          ),
          isEmpty,
        );
        // No list is ever empty.
        expect(
          reply.parts.whereType<FrontReplyCards>().every(
            (part) => part.cards.isNotEmpty,
          ),
          isTrue,
        );
        // Every attachment a lookup made, exactly once.
        final shows = [
          for (final part in reply.parts.whereType<FrontReplyShow>())
            part.attachment,
        ];
        expect(shows.toSet(), available);
        expect(shows.length, available.length);
        // Her words, in her order, are the reply's text.
        final words = [
          for (final part in parts)
            if (part case {'text': final String text}) '<$text>',
        ];
        expect(reply.text, words.join('\n\n'));
        expect(
          [
            for (final part in reply.parts.whereType<FrontReplyText>())
              part.markdown,
          ],
          words,
        );
      },
      tags: 'glados',
    );
  });
}

/// How the index and the lookups list [row]: `kind:id`.
String keyOf(FrontIndexRow row) => '${row.kind.wireName}:${row.id}';
