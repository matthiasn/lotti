import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_reference_links.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

void main() {
  const feed = FrontIndexRow(
    kind: FrontDestinationKind.task,
    id: '0b6f3c1e-7d5a-4f1e-9a51-1c2d3e4f5a6b',
    title: 'Feed the penguins',
  );
  const census = FrontIndexRow(
    kind: FrontDestinationKind.project,
    id: 'census-2026',
    title: 'Colony [census]',
  );
  const goal = FrontIndexRow(
    kind: FrontDestinationKind.goal,
    id: 'goal-1',
    title: 'Swim daily',
  );
  const rows = [feed, census, goal];
  const feedLink =
      '[Feed the penguins](lotti://task/0b6f3c1e-7d5a-4f1e-9a51-1c2d3e4f5a6b)';

  group('frontReferenceUrl', () {
    test('names the kind and the id', () {
      expect(
        frontReferenceUrl(FrontDestinationKind.task, 't-1'),
        'lotti://task/t-1',
      );
      expect(
        frontReferenceUrl(FrontDestinationKind.project, 'p-1'),
        'lotti://project/p-1',
      );
    });
  });

  group('linkFrontReferences', () {
    test('turns a recited task id into a link titled as listed', () {
      expect(
        linkFrontReferences('Due today: task:${feed.id}.', rows),
        'Due today: $feedLink.',
      );
      expect(
        linkFrontReferences('Due today: ${feed.id}', rows),
        'Due today: $feedLink',
      );
      expect(
        linkFrontReferences('Due today: `task:${feed.id}`', rows),
        'Due today: $feedLink',
      );
    });

    test('folds the title it follows in parentheses into one link', () {
      expect(
        linkFrontReferences(
          'Feed the penguins (task:${feed.id}) is due.',
          rows,
        ),
        '$feedLink is due.',
      );
      expect(
        linkFrontReferences('- **Feed the Penguins** (${feed.id})', rows),
        '- $feedLink',
      );
    });

    test('keeps the parentheses when another title precedes them', () {
      expect(
        linkFrontReferences('Due today (task:${feed.id})', rows),
        'Due today ($feedLink)',
      );
    });

    test('links a project, its label free of brackets', () {
      expect(
        linkFrontReferences('Filed under project:census-2026.', rows),
        'Filed under [Colony (census)](lotti://project/census-2026).',
      );
    });

    test('leaves links she already wrote, and their urls, alone', () {
      const text =
          'See $feedLink and [the census](lotti://project/census-2026)';
      expect(linkFrontReferences(text, rows), text);
    });

    test('links nothing the turn could not see, nor a goal', () {
      expect(
        linkFrontReferences('task:unknown-id and goal:goal-1 and goal-1', rows),
        'task:unknown-id and goal:goal-1 and goal-1',
      );
    });

    test('links a bare id only when no word could be it', () {
      const garden = FrontIndexRow(
        kind: FrontDestinationKind.task,
        id: 'garden',
        title: 'Garden',
      );
      expect(
        linkFrontReferences('The garden task, task:garden', [garden]),
        'The garden task, [Garden](lotti://task/garden)',
      );
    });

    test('never matches inside a longer word', () {
      expect(
        linkFrontReferences('xcensus-2026 and census-2026x', rows),
        'xcensus-2026 and census-2026x',
      );
    });

    test('is the text itself when there is nothing to link with', () {
      expect(
        linkFrontReferences('task:${feed.id}', const []),
        'task:${feed.id}',
      );
      expect(linkFrontReferences('', rows), '');
    });
  });
}
