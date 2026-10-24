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
}
