import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

void main() {
  FrontIndexRow task(String id, {String? oneLiner, DateTime? due}) =>
      FrontIndexRow(
        kind: FrontDestinationKind.task,
        id: id,
        title: 'Task $id',
        status: 'OPEN',
        oneLiner: oneLiner,
        due: due,
      );

  test('rows are sorted by id within each kind whatever the input order', () {
    final a = FrontRoutingIndex(tasks: [task('b'), task('a'), task('c')]);
    final b = FrontRoutingIndex(tasks: [task('c'), task('b'), task('a')]);
    expect(a.tasks.map((r) => r.id), ['a', 'b', 'c']);
    expect(a.render(), b.render());
  });

  test('the rendered block is one fixed format, one row per line', () {
    final index = FrontRoutingIndex(
      tasks: [
        task(
          't1',
          oneLiner: '  Waiting on\nthe   plumber ',
          due: DateTime(2026, 10, 3),
        ),
      ],
      projects: const [
        FrontIndexRow(
          kind: FrontDestinationKind.project,
          id: 'p1',
          title: 'Kitchen',
          oneLiner: 'Cabinets this week.',
          tldr: 'Never rendered here.',
        ),
      ],
      goals: const [
        FrontIndexRow(
          kind: FrontDestinationKind.goal,
          id: 'g1',
          title: '10k steps',
        ),
      ],
      people: const [
        FrontIndexRow(
          kind: FrontDestinationKind.person,
          id: 'r1',
          title: 'Pip',
        ),
      ],
    );
    expect(index.render(), '''
<routing_index>
## Tasks (1 shown)
- task:t1 | Task t1 | OPEN | due 2026-10-03 | Waiting on the plumber
## Projects (1 shown)
- project:p1 | Kitchen | Cabinets this week.
## Goals (1 shown)
- goal:g1 | 10k steps
## People (1 shown)
- person:r1 | Pip
</routing_index>''');
    // The TL;DR is held for read_tldr and never rendered into the block.
    expect(index.render(), isNot(contains('Never rendered')));
  });

  test('truncation is announced per kind, exact where the count is known', () {
    final index = FrontRoutingIndex(
      tasks: [task('t')],
      tasksTruncated: true,
      omittedProjects: 7,
    );
    final rendered = index.render();
    expect(
      rendered,
      contains('## Tasks (1 shown, more exist but are not shown)'),
    );
    expect(rendered, contains('## Projects (0 shown, +7 not shown)'));
    expect(rendered, contains('## Goals (0 shown)'));
  });

  test('contains and row look up by kind and id only', () {
    final index = FrontRoutingIndex(
      tasks: [task('shared')],
      goals: const [
        FrontIndexRow(kind: FrontDestinationKind.goal, id: 'g', title: 'G'),
      ],
    );
    expect(index.contains(FrontDestinationKind.task, 'shared'), isTrue);
    expect(index.contains(FrontDestinationKind.project, 'shared'), isFalse);
    expect(index.contains(FrontDestinationKind.day, 'shared'), isFalse);
    expect(index.row(FrontDestinationKind.goal, 'g')?.title, 'G');
    expect(index.row(FrontDestinationKind.goal, 'missing'), isNull);
    expect(index.rows.map((r) => r.id), ['shared', 'g']);
  });

  test("the caps are the plan's", () {
    expect(frontIndexMaxTasks, 200);
    expect(frontIndexMaxProjects, 50);
    expect(frontIndexMaxGoals, 50);
    expect(frontIndexMaxPeople, 50);
    expect(frontCorpusMatchLimit, 8);
  });

  group('categories', () {
    test('lead the block by name, the chosen ones marked and announced', () {
      final index = FrontRoutingIndex(
        categories: const [
          FrontCategory(id: 'c-w', name: 'work'),
          FrontCategory(id: 'c-c', name: 'Penguin  Colony', chosen: true),
        ],
      );

      expect(
        index.render(),
        startsWith('''
<routing_index>
## Categories (2; this conversation is narrowed to the chosen ones)
- category:c-c | Penguin Colony | chosen
- category:c-w | work
## Tasks (0 shown)'''),
      );
      expect(index.category('c-w')?.name, 'work');
      expect(index.category('missing'), isNull);
    });

    test('say nothing of narrowing when no chip is chosen', () {
      final rendered = FrontRoutingIndex(
        categories: const [FrontCategory(id: 'c-w', name: 'Work')],
      ).render();
      expect(rendered, contains('## Categories (1)\n- category:c-w | Work\n'));
      expect(rendered, isNot(contains('chosen')));
    });
  });

  test('a wire name reads back as its window, anything else as none', () {
    for (final window in FrontDueWindow.values) {
      expect(FrontDueWindow.fromWire(window.name), window);
    }
    expect(FrontDueWindow.fromWire('soon'), isNull);
    expect(FrontDueWindow.fromWire(null), isNull);
  });

  group('FrontDueTasks.render', () {
    final today = DateTime(2026, 11, 2);
    final late = FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'late',
      title: 'Fix   the\nfence',
      status: 'BLOCKED',
      categoryId: 'c-c',
      due: DateTime(2026, 10, 30),
    );
    final feed = FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'feed',
      title: 'Feed the penguins',
      due: DateTime(2026, 11, 3, 8),
    );

    test('all names the days, marks what is overdue, and counts the cut', () {
      final rendered = FrontDueTasks(
        window: FrontDueWindow.all,
        today: today,
        through: DateTime(2026, 11, 4),
        rows: [late, feed],
        omitted: 4,
        categoryNames: const {'c-c': 'Penguin Colony'},
      ).render();

      expect(
        rendered,
        'Open tasks overdue or due through 2026-11-04 (2, +4 not shown):\n'
        '- task:late | Fix the fence | BLOCKED | due 2026-10-30 (overdue) '
        '| Penguin Colony\n'
        '- task:feed | Feed the penguins | due 2026-11-03',
      );
    });

    test('overdue alone needs no mark: the heading says it', () {
      final rendered = FrontDueTasks(
        window: FrontDueWindow.overdue,
        today: today,
        through: today,
        rows: [late],
        narrowedTo: const ['Penguin Colony'],
      ).render();

      expect(
        rendered,
        'Open tasks overdue (due before 2026-11-02) in Penguin Colony (1):\n'
        '- task:late | Fix the fence | BLOCKED | due 2026-10-30',
      );
    });

    test('each window says plainly when it holds nothing', () {
      String empty(FrontDueWindow window, DateTime through) => FrontDueTasks(
        window: window,
        today: today,
        through: through,
        rows: const [],
      ).render();
      final later = DateTime(2026, 11, 9);

      expect(
        empty(FrontDueWindow.today, today),
        'None: no open task due today (2026-11-02).',
      );
      expect(
        empty(FrontDueWindow.overdue, today),
        'None: no open task overdue (due before 2026-11-02).',
      );
      expect(
        empty(FrontDueWindow.upcoming, today),
        'None: no open task due today (2026-11-02).',
      );
      expect(
        empty(FrontDueWindow.upcoming, later),
        'None: no open task due 2026-11-02 through 2026-11-09.',
      );
      expect(
        empty(FrontDueWindow.all, today),
        'None: no open task overdue or due today (2026-11-02).',
      );
      expect(
        FrontDueTasks(
          window: FrontDueWindow.today,
          today: today,
          through: today,
          rows: const [],
          narrowedTo: const ['Penguin Colony', 'Work'],
        ).render(),
        'None: no open task due today (2026-11-02) in Penguin Colony, Work.',
      );
    });
  });
}
